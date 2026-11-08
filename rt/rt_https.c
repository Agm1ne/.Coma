// rt_https.c — HTTPS GET minimo con TLS de verdad (Schannel en Windows).
// `coma_https_get(url, &salida)`: https://host[:puerto]/ruta -> cuerpo.
// Valida el certificado (nada de saltarse pasos), sigue hasta 3 saltos,
// tope 4MB. Errores duros = E106 + exit(1), nunca silencio.
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define SECURITY_WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <schannel.h>
#include <security.h>

#define HTTPS_MAX (4 << 20)
#define HTTPS_IO (16 * 1024)

static int wsa_ok = 0;

static void h106(const char* op, const char* det) {
    printf("E106 https %s: no se puede (%s)", op, det ? det : "?");
    coma_einfo();
    printf("\n");
    exit(1);
}

static void send_all(SOCKET s, const char* b, int n) {
    int off = 0;
    while (off < n) {
        int r = send(s, b + off, n - off, 0);
        if (r <= 0) h106("enviar", "corte al escribir");
        off += r;
    }
}

// Parte https://host[:puerto]/ruta. Devuelve 1 si vale. host/ruta a buffers.
static int parte_url(const char* url, char* host, int hn, int* port, char* path, int pn) {
    const char* p = url;
    if (!p || strncmp(p, "https://", 8) != 0) return 0;
    p += 8;
    int hi = 0;
    while (*p && *p != '/' && *p != ':' && hi + 1 < hn) host[hi++] = *p++;
    host[hi] = 0;
    if (hi == 0) return 0;
    *port = 443;
    if (*p == ':') {
        p++;
        int v = 0, nd = 0;
        while (*p >= '0' && *p <= '9') { v = v * 10 + (*p - '0'); p++; nd++; }
        if (nd == 0 || v <= 0 || v > 65535) return 0;
        *port = v;
    }
    if (*p == 0) { path[0] = '/'; path[1] = 0; return 1; }
    if (*p != '/') return 0;
    {
        int pi = 0;
        while (*p && pi + 1 < pn) path[pi++] = *p++;
        path[pi] = 0;
        return *p == 0;
    }
}

static SOCKET conecta(const char* host, int port) {
    struct addrinfo hints, *res = NULL, *rp;
    char ps[16];
    SOCKET s = INVALID_SOCKET;
    if (!wsa_ok) {
        WSADATA wd;
        if (WSAStartup(MAKEWORD(2, 2), &wd) != 0) h106("red", "sin Winsock");
        wsa_ok = 1;
    }
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    sprintf_s(ps, sizeof(ps), "%d", port);
    if (getaddrinfo(host, ps, &hints, &res) != 0 || !res)
        h106("resolver", host);
    for (rp = res; rp; rp = rp->ai_next) {
        s = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (s == INVALID_SOCKET) continue;
        {
            DWORD to = 15000;
            setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, (const char*)&to, sizeof(to));
            setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, (const char*)&to, sizeof(to));
        }
        if (connect(s, rp->ai_addr, (int)rp->ai_addrlen) == 0) break;
        closesocket(s);
        s = INVALID_SOCKET;
    }
    freeaddrinfo(res);
    if (s == INVALID_SOCKET) h106("conectar", host);
    return s;
}

typedef struct {
    CredHandle cred;
    CtxtHandle ctx;
    int tiene_ctx;
    int tiene_cred;
} TlsSesi;

static void tls_cierra(TlsSesi* t, SOCKET s) {
    if (t->tiene_ctx) { DeleteSecurityContext(&t->ctx); t->tiene_ctx = 0; }
    if (t->tiene_cred) { FreeCredentialsHandle(&t->cred); t->tiene_cred = 0; }
    if (s != INVALID_SOCKET) closesocket(s);
}

static void aprieta_manos(TlsSesi* t, SOCKET s, const char* host) {
    SCHANNEL_CRED cred;
    TimeStamp ts;
    memset(&cred, 0, sizeof(cred));
    cred.dwVersion = SCHANNEL_CRED_VERSION;
    if (AcquireCredentialsHandleA(NULL, (SEC_CHAR*)UNISP_NAME_A, SECPKG_CRED_OUTBOUND,
                                  NULL, &cred, NULL, NULL, &t->cred, &ts) != SEC_E_OK)
        h106("tls", "sin credenciales");
    t->tiene_cred = 1;
    {
        char io[HTTPS_IO];
        int iolen = 0;
        int primera = 1;
        for (;;) {
            SecBufferDesc outD, inD;
            SecBuffer outB, inB[2];
            SECURITY_STATUS sc;
            DWORD attr = 0;
            outB.BufferType = SECBUFFER_TOKEN;
            outB.cbBuffer = 0;
            outB.pvBuffer = NULL;
            outD.ulVersion = SECBUFFER_VERSION;
            outD.cBuffers = 1;
            outD.pBuffers = &outB;
            inD.ulVersion = SECBUFFER_VERSION;
            if (primera) {
                inD.cBuffers = 0;
                inD.pBuffers = NULL;
            } else {
                inB[0].BufferType = SECBUFFER_TOKEN;
                inB[0].cbBuffer = (unsigned long)iolen;
                inB[0].pvBuffer = io;
                inB[1].BufferType = SECBUFFER_EMPTY;
                inB[1].cbBuffer = 0;
                inB[1].pvBuffer = NULL;
                inD.cBuffers = 2;
                inD.pBuffers = inB;
            }
            sc = InitializeSecurityContextA(&t->cred, primera ? NULL : &t->ctx,
                                            (SEC_CHAR*)host,
                                            ISC_REQ_SEQUENCE_DETECT | ISC_REQ_REPLAY_DETECT |
                                            ISC_REQ_CONFIDENTIALITY | ISC_REQ_ALLOCATE_MEMORY |
                                            ISC_REQ_STREAM,
                                            0, SECURITY_NATIVE_DREP,
                                            primera ? NULL : &inD, 0,
                                            primera ? &t->ctx : NULL, &outD, &attr, &ts);
            if (primera) t->tiene_ctx = 1;
            primera = 0;
            if (outB.cbBuffer > 0 && outB.pvBuffer) {
                send_all(s, (const char*)outB.pvBuffer, (int)outB.cbBuffer);
                FreeContextBuffer(outB.pvBuffer);
            }
            if (sc == SEC_E_OK) {
                // Sobrante tras el token (datos de app tempranos): se guarda.
                if (inD.cBuffers == 2 && inB[1].BufferType == SECBUFFER_EXTRA &&
                    inB[1].cbBuffer > 0 && inB[1].pvBuffer) {
                    unsigned long x = inB[1].cbBuffer;
                    if (x > (unsigned long)sizeof(io)) x = (unsigned long)sizeof(io);
                    memmove(io, inB[1].pvBuffer, x);
                    iolen = (int)x;
                } else {
                    iolen = 0;
                }
                break;
            }
            if (sc != SEC_I_CONTINUE_NEEDED) {
                char det[64];
                sprintf_s(det, sizeof(det), "apreton roto (0x%08lx)", (unsigned long)sc);
                h106("tls", det);
            }
            // Mas bytes del servidor: el sobrante (EXTRA) se conserva y el
            // resto se DESCARTA (ya consumido); si no, el token lleva basura.
            if (inD.cBuffers == 2 && inB[1].BufferType == SECBUFFER_EXTRA &&
                inB[1].cbBuffer > 0 && inB[1].pvBuffer) {
                unsigned long x = inB[1].cbBuffer;
                if (x > (unsigned long)sizeof(io)) h106("tls", "token enorme");
                memmove(io, inB[1].pvBuffer, x);
                iolen = (int)x;
            } else {
                iolen = 0;
            }
            {
                int r = recv(s, io + iolen, (int)sizeof(io) - iolen, 0);
                if (r <= 0) h106("tls", "corte en el apreton");
                iolen += r;
            }
        }
    }
    // El certificado se VERIFICA (nada de fiarse a ciegas).
    {
        PCCERT_CONTEXT remoto = NULL;
        if (QueryContextAttributesA(&t->ctx, SECPKG_ATTR_REMOTE_CERT_CONTEXT, &remoto) != SEC_E_OK || !remoto)
            h106("tls", "sin certificado");
        {
            wchar_t wh[256];
            HTTPSPolicyCallbackData pol;
            CERT_CHAIN_POLICY_PARA para;
            CERT_CHAIN_POLICY_STATUS estado;
            PCCERT_CHAIN_CONTEXT cadena = NULL;
            CERT_CHAIN_PARA cpar;
            MultiByteToWideChar(CP_UTF8, 0, host, -1, wh, 256);
            memset(&pol, 0, sizeof(pol));
            pol.cbStruct = sizeof(pol);
            pol.dwAuthType = AUTHTYPE_SERVER;
            pol.pwszServerName = wh;
            memset(&para, 0, sizeof(para));
            para.cbSize = sizeof(para);
            para.pvExtraPolicyPara = &pol;
            memset(&estado, 0, sizeof(estado));
            estado.cbSize = sizeof(estado);
            memset(&cpar, 0, sizeof(cpar));
            cpar.cbSize = sizeof(cpar);
            if (!CertGetCertificateChain(NULL, remoto, NULL, remoto->hCertStore, &cpar, 0, NULL, &cadena))
                h106("tls", "cadena rota");
            if (!CertVerifyCertificateChainPolicy(CERT_CHAIN_POLICY_SSL, cadena, &para, &estado) || estado.dwError != 0)
                h106("tls", "certificado no valido");
            CertFreeCertificateChain(cadena);
        }
        CertFreeCertificateContext(remoto);
    }
}

static void manda_get(TlsSesi* t, SOCKET s, const char* host, const char* path) {
    SecPkgContext_StreamSizes tm;
    char pet[2048];
    int pl;
    if (QueryContextAttributesA(&t->ctx, SECPKG_ATTR_STREAM_SIZES, &tm) != SEC_E_OK)
        h106("enviar", "sin medidas");
    pl = snprintf(pet, sizeof(pet),
                  "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\nUser-Agent: Coma/1.0\r\n\r\n",
                  path, host);
    if (pl <= 0 || pl >= (int)sizeof(pet)) h106("enviar", "peticion larga");
    {
        unsigned long todo = (unsigned long)tm.cbHeader + (unsigned long)pl + (unsigned long)tm.cbTrailer;
        char* buf = (char*)malloc(todo);
        SecBuffer bfr[4];
        SecBufferDesc desc;
        if (!buf) exit(1);
        memcpy(buf + tm.cbHeader, pet, (size_t)pl);
        bfr[0].BufferType = SECBUFFER_STREAM_HEADER;
        bfr[0].cbBuffer = tm.cbHeader;
        bfr[0].pvBuffer = buf;
        bfr[1].BufferType = SECBUFFER_DATA;
        bfr[1].cbBuffer = (unsigned long)pl;
        bfr[1].pvBuffer = buf + tm.cbHeader;
        bfr[2].BufferType = SECBUFFER_STREAM_TRAILER;
        bfr[2].cbBuffer = tm.cbTrailer;
        bfr[2].pvBuffer = buf + tm.cbHeader + pl;
        bfr[3].BufferType = SECBUFFER_EMPTY;
        bfr[3].cbBuffer = 0;
        bfr[3].pvBuffer = NULL;
        desc.ulVersion = SECBUFFER_VERSION;
        desc.cBuffers = 4;
        desc.pBuffers = bfr;
        if (EncryptMessage(&t->ctx, 0, &desc, 0) != SEC_E_OK) {
            free(buf);
            h106("enviar", "cifrado roto");
        }
        send_all(s, buf, (int)(bfr[0].cbBuffer + bfr[1].cbBuffer + bfr[2].cbBuffer));
        free(buf);
    }
}

static void manda_post(TlsSesi* t, SOCKET s, const char* host, const char* path,
                       const char* body, const char* contentType) {
    SecPkgContext_StreamSizes tm;
    char pet[4096];
    int pl;
    if (QueryContextAttributesA(&t->ctx, SECPKG_ATTR_STREAM_SIZES, &tm) != SEC_E_OK)
        h106("enviar", "sin medidas");
    pl = snprintf(pet, sizeof(pet),
                  "POST %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n"
                  "User-Agent: Coma/1.0\r\nContent-Type: %s\r\nContent-Length: %zu\r\n\r\n%s",
                  path, host, contentType ? contentType : "application/json",
                  body ? strlen(body) : 0, body ? body : "");
    if (pl <= 0 || pl >= (int)sizeof(pet)) h106("enviar", "peticion larga");
    {
        unsigned long todo = (unsigned long)tm.cbHeader + (unsigned long)pl + (unsigned long)tm.cbTrailer;
        char* buf = (char*)malloc(todo);
        SecBuffer bfr[4];
        SecBufferDesc desc;
        if (!buf) exit(1);
        memcpy(buf + tm.cbHeader, pet, (size_t)pl);
        bfr[0].BufferType = SECBUFFER_STREAM_HEADER;
        bfr[0].cbBuffer = tm.cbHeader;
        bfr[0].pvBuffer = buf;
        bfr[1].BufferType = SECBUFFER_DATA;
        bfr[1].cbBuffer = (unsigned long)pl;
        bfr[1].pvBuffer = buf + tm.cbHeader;
        bfr[2].BufferType = SECBUFFER_STREAM_TRAILER;
        bfr[2].cbBuffer = tm.cbTrailer;
        bfr[2].pvBuffer = buf + tm.cbHeader + pl;
        bfr[3].BufferType = SECBUFFER_EMPTY;
        bfr[3].cbBuffer = 0;
        bfr[3].pvBuffer = NULL;
        desc.ulVersion = SECBUFFER_VERSION;
        desc.cBuffers = 4;
        desc.pBuffers = bfr;
        if (EncryptMessage(&t->ctx, 0, &desc, 0) != SEC_E_OK) {
            free(buf);
            h106("enviar", "cifrado roto");
        }
        send_all(s, buf, (int)(bfr[0].cbBuffer + bfr[1].cbBuffer + bfr[2].cbBuffer));
        free(buf);
    }
}

// Lee todo hasta cierre/alerta; devuelve bytes crudos (con cabeceras).
static char* lee_todo(TlsSesi* t, SOCKET s, size_t* fuera_n) {
    size_t cap = 65536, len = 0;
    char* out = (char*)malloc(cap);
    char io[HTTPS_IO];
    int iolen = 0;
    if (!out) exit(1);
    for (;;) {
        SecBuffer bfr[4];
        SecBufferDesc desc;
        SECURITY_STATUS sc;
        int i;
        if (iolen == 0) {
            int r = recv(s, io, (int)sizeof(io), 0);
            if (r == 0) break; // cierre limpio
            if (r < 0) h106("recibir", "corte al leer");
            iolen = r;
        }
        bfr[0].BufferType = SECBUFFER_DATA;
        bfr[0].cbBuffer = (unsigned long)iolen;
        bfr[0].pvBuffer = io;
        for (i = 1; i < 4; i++) {
            bfr[i].BufferType = SECBUFFER_EMPTY;
            bfr[i].cbBuffer = 0;
            bfr[i].pvBuffer = NULL;
        }
        desc.ulVersion = SECBUFFER_VERSION;
        desc.cBuffers = 4;
        desc.pBuffers = bfr;
        sc = DecryptMessage(&t->ctx, &desc, 0, NULL);
        if (sc == SEC_E_INCOMPLETE_MESSAGE) {
            if (iolen >= (int)sizeof(io)) h106("recibir", "registro enorme");
            {
                int r = recv(s, io + iolen, (int)sizeof(io) - iolen, 0);
                if (r <= 0) h106("recibir", "corte a medias");
                iolen += r;
            }
            continue;
        }
        if (sc == SEC_I_CONTEXT_EXPIRED) break; // close_notify
        if (sc != SEC_E_OK && sc != SEC_I_RENEGOTIATE) h106("recibir", "descifrado roto");
        {
            int extra = 0;
            for (i = 0; i < 4; i++) {
                if (bfr[i].BufferType == SECBUFFER_DATA && bfr[i].cbBuffer > 0) {
                    if (len + bfr[i].cbBuffer > HTTPS_MAX) h106("recibir", "respuesta enorme (tope 4MB)");
                    while (len + bfr[i].cbBuffer + 1 > cap) {
                        cap *= 2;
                        {
                            char* np = (char*)realloc(out, cap);
                            if (!np) { free(out); exit(1); }
                            out = np;
                        }
                    }
                    memcpy(out + len, bfr[i].pvBuffer, bfr[i].cbBuffer);
                    len += bfr[i].cbBuffer;
                } else if (bfr[i].BufferType == SECBUFFER_EXTRA && bfr[i].cbBuffer > 0) {
                    unsigned long x = bfr[i].cbBuffer;
                    if (x > (unsigned long)sizeof(io)) h106("recibir", "sobrante enorme");
                    memmove(io, bfr[i].pvBuffer, x);
                    extra = (int)x;
                }
            }
            iolen = extra;
        }
    }
    if (out) {
        if (len + 1 > cap) {
            char* np = (char*)realloc(out, len + 1);
            if (!np) { free(out); exit(1); }
            out = np;
        }
        out[len] = 0;
    }
    *fuera_n = len;
    return out;
}

// Estado HTTP (200, 301...). -1 si no se entiende.
static int estado_http(const char* r) {
    if (!r || strncmp(r, "HTTP/", 5) != 0) return -1;
    {
        const char* sp = strchr(r, ' ');
        if (!sp) return -1;
        return atoi(sp + 1);
    }
}

// Valor de la cabecera Nombre (hasta fin de linea, sin \r). "" si falta.
static void cabecera(const char* r, const char* nombre, char* fuera, int fn) {
    size_t nl = strlen(nombre);
    const char* p = r;
    fuera[0] = 0;
    while (*p) {
        const char* fin = strstr(p, "\r\n");
        size_t ll = fin ? (size_t)(fin - p) : strlen(p);
        if (ll > nl + 1 && _strnicmp(p, nombre, nl) == 0 && p[nl] == ':') {
            const char* v = p + nl + 1;
            while (*v == ' ' || *v == '\t') v++;
            {
                size_t n = fin ? (size_t)(fin - v) : strlen(v);
                if (n >= (size_t)fn) n = (size_t)fn - 1;
                memcpy(fuera, v, n);
                fuera[n] = 0;
                while (n > 0 && (fuera[n-1] == ' ' || fuera[n-1] == '\t')) fuera[--n] = 0;
            }
            return;
        }
        if (!fin) break;
        p = fin + 2;
    }
}

void coma_https_get(const char* url, char** salida) {
    char cur[2048], host[256], ruta[2048], loc[2048];
    int puerto = 443, salto;
    if (!url || !url[0]) h106("traer", "url vacia");
    if (strlen(url) >= sizeof(cur)) h106("traer", "url larga");
    strcpy_s(cur, sizeof(cur), url);
    for (salto = 0; salto < 4; salto++) {
        TlsSesi tls;
        SOCKET s;
        char* crudo = NULL;
        size_t n = 0;
        int est;
        memset(&tls, 0, sizeof(tls));
        if (!parte_url(cur, host, sizeof(host), &puerto, ruta, sizeof(ruta)))
            h106("traer", "url mala (https://host/ruta)");
        s = conecta(host, puerto);
        aprieta_manos(&tls, s, host);
        manda_get(&tls, s, host, ruta);
        crudo = lee_todo(&tls, s, &n);
        tls_cierra(&tls, s);
        if (!crudo) h106("traer", "sin respuesta");
        est = estado_http(crudo);
        if (est == 200) {
            const char* cuerpo = strstr(crudo, "\r\n\r\n");
            char* p;
            if (!cuerpo) { free(crudo); h106("traer", "respuesta rota"); }
            cuerpo += 4;
            p = (char*)malloc(strlen(cuerpo) + 1);
            if (!p) { free(crudo); exit(1); }
            strcpy_s(p, strlen(cuerpo) + 1, cuerpo);
            free(crudo);
            free(*salida);
            *salida = p;
            return;
        }
        if ((est == 301 || est == 302 || est == 303 || est == 307 || est == 308) && salto < 3) {
            cabecera(crudo, "Location", loc, sizeof(loc));
            free(crudo);
            if (!loc[0]) h106("traer", "salto sin destino");
            if (strncmp(loc, "https://", 8) == 0) {
                if (strlen(loc) >= sizeof(cur)) h106("traer", "salto largo");
                strcpy_s(cur, sizeof(cur), loc);
            } else if (loc[0] == '/') {
                char base[512];
                if (puerto != 443) sprintf_s(base, sizeof(base), "https://%s:%d", host, puerto);
                else sprintf_s(base, sizeof(base), "https://%s", host);
                if (strlen(base) + strlen(loc) >= sizeof(cur)) h106("traer", "salto largo");
                strcpy_s(cur, sizeof(cur), base);
                strcat_s(cur, sizeof(cur), loc);
            } else {
                h106("traer", "salto raro (solo https o /ruta)");
            }
            continue;
        }
        {
            char det[64];
            sprintf_s(det, sizeof(det), "HTTP %d", est);
            free(crudo);
            h106("traer", det);
        }
    }
    h106("traer", "demasiados saltos");
}

void coma_https_post(const char* url, const char* body, const char* contentType, char** salida) {
    char cur[2048], host[256], ruta[2048];
    int puerto = 443, salto;
    if (!url || !url[0]) h106("enviar", "url vacia");
    if (strlen(url) >= sizeof(cur)) h106("enviar", "url larga");
    strcpy_s(cur, sizeof(cur), url);
    for (salto = 0; salto < 4; salto++) {
        TlsSesi tls;
        SOCKET s;
        char* crudo = NULL;
        size_t n = 0;
        int est;
        memset(&tls, 0, sizeof(tls));
        if (!parte_url(cur, host, sizeof(host), &puerto, ruta, sizeof(ruta)))
            h106("enviar", "url mala (https://host/ruta)");
        s = conecta(host, puerto);
        aprieta_manos(&tls, s, host);
        manda_post(&tls, s, host, ruta, body, contentType);
        crudo = lee_todo(&tls, s, &n);
        tls_cierra(&tls, s);
        if (!crudo) h106("enviar", "sin respuesta");
        est = estado_http(crudo);
        if (est == 200) {
            const char* cuerpo = strstr(crudo, "\r\n\r\n");
            char* p;
            if (!cuerpo) { free(crudo); h106("enviar", "respuesta rota"); }
            cuerpo += 4;
            p = (char*)malloc(strlen(cuerpo) + 1);
            if (!p) { free(crudo); exit(1); }
            strcpy_s(p, strlen(cuerpo) + 1, cuerpo);
            free(crudo);
            free(*salida);
            *salida = p;
            return;
        }
        if ((est == 301 || est == 302 || est == 303 || est == 307 || est == 308) && salto < 3) {
            cabecera(crudo, "Location", ruta, sizeof(ruta));
            free(crudo);
            if (!ruta[0]) h106("enviar", "salto sin destino");
            if (strncmp(ruta, "https://", 8) == 0) {
                if (strlen(ruta) >= sizeof(cur)) h106("enviar", "salto largo");
                strcpy_s(cur, sizeof(cur), ruta);
            } else if (ruta[0] == '/') {
                char base[512];
                if (puerto != 443) sprintf_s(base, sizeof(base), "https://%s:%d", host, puerto);
                else sprintf_s(base, sizeof(base), "https://%s", host);
                if (strlen(base) + strlen(ruta) >= sizeof(cur)) h106("enviar", "salto largo");
                strcpy_s(cur, sizeof(cur), base);
                strcat_s(cur, sizeof(cur), ruta);
            } else {
                h106("enviar", "salto raro (solo https o /ruta)");
            }
            continue;
        }
        {
            char det[64];
            sprintf_s(det, sizeof(det), "HTTP %d", est);
            free(crudo);
            h106("enviar", det);
        }
    }
    h106("enviar", "demasiados saltos");
}

#else
// Sin Windows no hay Schannel: error honesto, nunca silencio.
#include <stdio.h>
#include <stdlib.h>
void coma_https_get(const char* url, char** salida) {
    (void)url;
    (void)salida;
    printf("E106 https traer: el https solo esta en Windows (Schannel)");
    coma_einfo();
    printf("\n");
    exit(1);
}
void coma_https_post(const char* url, const char* body, const char* contentType, char** salida) {
    (void)url;
    (void)body;
    (void)contentType;
    (void)salida;
    printf("E106 https enviar: el https solo esta en Windows (Schannel)");
    coma_einfo();
    printf("\n");
    exit(1);
}
#endif
