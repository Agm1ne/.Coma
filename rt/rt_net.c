/* rt_net.c — red de .Coma (sesión única TCP, portable, libc + ws2_32 en Windows).
   conectar "host" puerto. / enviar X. (línea + salto) / recibir Var. (línea; fin/timeout = "")
   / desconectar. Sin handle en el lenguaje a propósito (los vagos no los siguen);
   conectar cierra la anterior sola; al salir se cierra sola. Todo error duro es
   E106 + exit(1), nunca silencio. LÍMITE HONESTO: solo TCP cliente (sin servidor,
   sin UDP); enviar añade salto de línea; recibir corta en 15 s con "" (no error). */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
typedef SOCKET sock_t;
#define SOCK_BAD INVALID_SOCKET
#define SOCK_CLOSE(s) closesocket(s)
#else
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <sys/time.h>
#include <sys/stat.h>
typedef int sock_t;
#define SOCK_BAD (-1)
#define SOCK_CLOSE(s) close(s)
#endif

#define NET_TIMEOUT_S 15

static sock_t cur = SOCK_BAD;
static int reg = 0;

static void e106(const char *op, const char *p) {
    printf("E106 %s: no se puede (%s). Revisa host, puerto y conexion (prueba con ping).\n",
           op, (p && p[0]) ? p : "?");
    fflush(stdout);
    exit(1);
}

static void autocierra(void) {
#ifdef _WIN32
    if (cur != SOCK_BAD) {
        SOCK_CLOSE(cur);
        cur = SOCK_BAD;
        WSACleanup();
    }
#else
    if (cur != SOCK_BAD) {
        SOCK_CLOSE(cur);
        cur = SOCK_BAD;
    }
#endif
}

static void regonce(void) {
    if (!reg) {
        atexit(autocierra);
        reg = 1;
    }
}

static void strip_nl(char *b) { b[strcspn(b, "\r\n")] = 0; }

void coma_net_connect(const char *host, int port) {
    char ports[16];
    struct addrinfo hints, *list = 0, *ai;
    if (!host || !host[0]) e106("conectar", host);
    if (port <= 0 || port > 65535) e106("conectar", "puerto 1..65535");
    regonce();
    autocierra();
#ifdef _WIN32
    {
        WSADATA wd;
        if (WSAStartup(MAKEWORD(2, 2), &wd) != 0) e106("conectar", host);
    }
#endif
    snprintf(ports, sizeof ports, "%d", port);
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    if (getaddrinfo(host, ports, &hints, &list) != 0 || !list) {
#ifdef _WIN32
        WSACleanup();
#endif
        e106("conectar", host);
    }
    for (ai = list; ai; ai = ai->ai_next) {
        sock_t s = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (s == SOCK_BAD) continue;
        if (connect(s, ai->ai_addr, (int)ai->ai_addrlen) == 0) {
            cur = s;
            break;
        }
        SOCK_CLOSE(s);
    }
    freeaddrinfo(list);
    if (cur == SOCK_BAD) {
#ifdef _WIN32
        WSACleanup();
#endif
        e106("conectar", host);
    }
#ifdef _WIN32
    {
        DWORD to = NET_TIMEOUT_S * 1000;
        setsockopt(cur, SOL_SOCKET, SO_RCVTIMEO, (const char *)&to, sizeof to);
    }
#else
    {
        struct timeval to;
        to.tv_sec = NET_TIMEOUT_S;
        to.tv_usec = 0;
        setsockopt(cur, SOL_SOCKET, SO_RCVTIMEO, &to, sizeof to);
    }
#endif
}

static void send_all(const char *b, size_t n) {
    size_t sent = 0;
    if (cur == SOCK_BAD) e106("enviar", "sin conectar");
    while (sent < n) {
#ifdef _WIN32
        int r = send(cur, b + sent, (int)(n - sent), 0);
#else
        ssize_t r = send(cur, b + sent, n - sent, 0);
#endif
        if (r <= 0) e106("enviar", "conexion perdida");
        sent += (size_t)r;
    }
}

void coma_net_send_str(const char *s) {
    if (!s) s = "";
    send_all(s, strlen(s));
    send_all("\r\n", 2);
}

void coma_net_send_int(int v) {
    char b[64];
    snprintf(b, sizeof b, "%d", v);
    send_all(b, strlen(b));
    send_all("\r\n", 2);
}

void coma_net_send_dbl(double v) {
    char b[64];
    snprintf(b, sizeof b, "%g", v);
    send_all(b, strlen(b));
    send_all("\r\n", 2);
}

void coma_net_recv(char **dst) {
    size_t cap = 256, len = 0;
    char *p;
    if (cur == SOCK_BAD) e106("recibir", "sin conectar");
    p = (char *)malloc(cap);
    if (!p) exit(1);
    p[0] = 0;
    for (;;) {
        char c;
#ifdef _WIN32
        int r = recv(cur, &c, 1, 0);
#else
        ssize_t r = recv(cur, &c, 1, 0);
#endif
        if (r <= 0) break; /* fin, cierre o timeout: se devuelve lo que haya */
        if (c == '\n') break;
        if (len + 2 > cap) {
            char *np;
            cap *= 2;
            np = (char *)realloc(p, cap);
            if (!np) { free(p); exit(1); }
            p = np;
        }
        p[len++] = c;
        p[len] = 0;
    }
    strip_nl(p);
    free(*dst);
    *dst = p;
}

void coma_net_close(void) { autocierra(); }

/* Servidor TCP minimal para COMA */
static int srv_wsa_init(void) {
#ifdef _WIN32
    WSADATA wd; if (WSAStartup(MAKEWORD(2,2), &wd) != 0) return -1;
#endif
    return 0;
}
int coma_srv_start(int port) {
    if (srv_wsa_init() != 0) return -1;
    sock_t s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == SOCK_BAD) return -1;
    int opt = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (const char*)&opt, sizeof(opt));
    struct sockaddr_in addr; memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET; addr.sin_addr.s_addr = htonl(INADDR_ANY); addr.sin_port = htons(port);
    if (bind(s, (struct sockaddr*)&addr, sizeof(addr)) != 0) { SOCK_CLOSE(s); return -1; }
    if (listen(s, 16) != 0) { SOCK_CLOSE(s); return -1; }
    return (int)s;
}
int coma_srv_accept(int srv) {
    struct sockaddr_in caddr; socklen_t clen = sizeof(caddr);
    sock_t c = accept((sock_t)srv, (struct sockaddr*)&caddr, &clen);
    if (c == SOCK_BAD) return -1;
    return (int)c;
}
int coma_srv_read(int client, char *buf, int maxlen) {
    if (maxlen <= 0) return 0;
    printf("C_SRV_READ: client=%d buf=%p maxlen=%d\n", client, (void*)buf, maxlen); fflush(stdout);
    int n = recv((sock_t)client, buf, maxlen-1, 0);
#ifdef _WIN32
    printf("C_SRV_READ: recv=%d err=%d\n", n, n==-1?(int)WSAGetLastError():0); fflush(stdout);
#else
    printf("C_SRV_READ: recv=%d err=%d\n", n, n==-1?errno:0); fflush(stdout);
#endif
    if (n > 0) buf[n] = 0; else if (n == 0) buf[0] = 0;
    return n;
}
int coma_srv_write(int client, const char *data) {
    if (!data) return 0;
    return (int)send((sock_t)client, data, (int)strlen(data), 0);
}
void coma_srv_close(int sock) { if (sock >= 0) SOCK_CLOSE((sock_t)sock); }

/* Servidor HTTP minimal: sirve un archivo en port */
void coma_http_serve(int port, const char *filePath) {
    int srv = coma_srv_start(port);
    if (srv < 0) { printf("no se pudo iniciar servidor\n"); return; }
    printf("Servidor en http://localhost:%d/\n", port);
    char buf[4096];
    while (1) {
        int c = coma_srv_accept(srv);
        if (c < 0) continue;
        coma_srv_read(c, buf, sizeof(buf));
        FILE *f = fopen(filePath, "rb");
        if (!f) { coma_srv_write(c, "HTTP/1.1 404 Not Found\r\n\r\n"); coma_srv_close(c); continue; }
        fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
        char *content = (char*)malloc(sz+1); fread(content, 1, sz, f); content[sz] = 0; fclose(f);
        char header[256]; snprintf(header, sizeof(header), "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %ld\r\n\r\n", sz);
        coma_srv_write(c, header);
        coma_srv_write(c, content);
        free(content);
        coma_srv_close(c);
    }
}
char *coma_srv_read_str(int client) {
    char *buf = (char*)malloc(8193);
    int total = 0;
    int content_len = 0;
    buf[0] = 0;
    /* Read until we have headers + body */
    while (total < 8192) {
        int n = recv((sock_t)client, buf + total, 8192 - total - 1, 0);
        if (n <= 0) break;
        total += n;
        buf[total] = 0;
        /* Check if we have complete headers */
        char *hdr_end = strstr(buf, "\r\n\r\n");
        if (hdr_end) {
            /* Parse Content-Length */
            char *cl = strstr(buf, "Content-Length:");
            if (cl) {
                content_len = atoi(cl + 15);
            } else {
                cl = strstr(buf, "content-length:");
                if (cl) content_len = atoi(cl + 15);
            }
            /* Check if we have the full body */
            int body_start = (int)(hdr_end - buf) + 4;
            int body_received = total - body_start;
            if (body_received >= content_len) break;
        }
    }
    if (total == 0) buf[0] = 0;
    else buf[total] = 0;
    return buf;
}


/* === Helpers para servidor Agmine Coin (srv_helpers) === */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Envío de entero como texto (Coma no tiene itoa) */
void srv_send_int(int client, int v) {
    char b[64];
    snprintf(b, sizeof b, "%d", v);
    send((sock_t)client, b, (int)strlen(b), 0);
}

void srv_send_str(int client, const char *s) {
    if (!s) s = "";
    send((sock_t)client, s, (int)strlen(s), 0);
}

/* Detección de tipo de petición */
int srv_is_options(char *buf) {
    if (!buf) return 0;
    return (strncmp(buf, "OPTIONS", 7) == 0) ? 1 : 0;
}

int srv_is_post(char *buf) {
    if (!buf) return 0;
    return (strncmp(buf, "POST", 4) == 0) ? 1 : 0;
}

int srv_is_get(char *buf) {
    if (!buf) return 0;
    return (strncmp(buf, "GET", 3) == 0) ? 1 : 0;
}

/* Extracción de la ruta de la petición */
char *srv_get_path(char *buf) {
    static char path[256];
    char *start, *end;
    path[0] = 0;
    if (!buf) return path;
    start = strchr(buf, ' ');
    if (!start) return path;
    start++;
    end = strchr(start, ' ');
    if (!end) return path;
    int len = (int)(end - start);
    if (len >= 255) len = 255;
    memcpy(path, start, len);
    path[len] = 0;
    return path;
}

/* Extracción del cuerpo HTTP (después de \r\n\r\n) */
char *srv_get_body(char *buf) {
    char *p;
    if (!buf) return buf;
    p = strstr(buf, "\r\n\r\n");
    if (p) return p + 4;
    p = strstr(buf, "\n\n");
    if (p) return p + 2;
    return buf;
}

/* Respuesta HTTP estándar con CORS */
void srv_respond(int client, const char *body) {
    char header[256];
    int blen = body ? (int)strlen(body) : 0;
    snprintf(header, sizeof header,
        "HTTP/1.1 200 OK\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        "Access-Control-Allow-Headers: Content-Type\r\n"
        "Content-Type: text/plain; charset=utf-8\r\n"
        "Content-Length: %d\r\n"
        "Connection: close\r\n\r\n", blen);
    send((sock_t)client, header, (int)strlen(header), 0);
    if (body && body[0]) send((sock_t)client, body, blen, 0);
}

/* Respuesta para preflight CORS (OPTIONS) */
void srv_cors_preflight(int client) {
    const char *resp =
        "HTTP/1.1 204 No Content\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        "Access-Control-Allow-Headers: Content-Type\r\n"
        "Connection: close\r\n\r\n";
    send((sock_t)client, resp, (int)strlen(resp), 0);
}

/* Envío de headers HTTP 200 */
void srv_send_headers(int client) {
    const char *hdr =
        "HTTP/1.1 200 OK\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        "Access-Control-Allow-Headers: Content-Type\r\n"
        "Content-Type: text/plain; charset=utf-8\r\n"
        "Connection: close\r\n\r\n";
    send((sock_t)client, hdr, (int)strlen(hdr), 0);
}

/* Conversión de texto a entero */
int srv_atoi(const char *s) {
    if (!s) return 0;
    return atoi(s);
}

/* Búsqueda de subcadena */
int srv_str_find(const char *s, const char *sub) {
    if (!s || !sub) return -1;
    char *p = strstr(s, sub);
    if (!p) return -1;
    return (int)(p - s);
}

/* Extracción de subcadena */
char *srv_str_sub(const char *s, int start, int len) {
    static char buf[4096];
    int slen;
    if (!s) { buf[0] = 0; return buf; }
    slen = (int)strlen(s);
    if (start < 0) start = 0;
    if (start > slen) start = slen;
    if (len < 0) len = 0;
    if (start + len > slen) len = slen - start;
    if (len > 4095) len = 4095;
    memcpy(buf, s + start, len);
    buf[len] = 0;
    return buf;
}

/* Hash FNV-1a */
unsigned int srv_hash(const char *s) {
    unsigned int h = 2166136261u;
    if (!s) return h;
    while (*s) {
        h ^= (unsigned char)*s;
        h *= 16777619u;
        s++;
    }
    return h;
}

/* Comparación insensible a mayúsculas */
int srv_stricmp(const char *a, const char *b) {
    if (!a) a = "";
    if (!b) b = "";
#ifdef _WIN32
    return _stricmp(a, b);
#else
    return strcasecmp(a, b);
#endif
}

/* Lectura de archivo como texto */
char *srv_read_file(const char *path) {
    static char *buf = NULL;
    FILE *f;
    long sz;
    if (buf) { free(buf); buf = NULL; }
    f = fopen(path, "rb");
    if (!f) return (char*)"";
    fseek(f, 0, SEEK_END);
    sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0 || sz > 1000000) { fclose(f); return (char*)""; }
    buf = (char*)malloc(sz + 1);
    if (!buf) { fclose(f); return (char*)""; }
    fread(buf, 1, sz, f);
    buf[sz] = 0;
    fclose(f);
    return buf;
}

/* Respuesta HTTP para HTML */
void srv_respond_html(int client, const char *body) {
    char header[256];
    int blen = body ? (int)strlen(body) : 0;
    snprintf(header, sizeof header,
        "HTTP/1.1 200 OK\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Content-Type: text/html; charset=utf-8\r\n"
        "Content-Length: %d\r\n"
        "Connection: close\r\n\r\n", blen);
    send((sock_t)client, header, (int)strlen(header), 0);
    if (body && body[0]) send((sock_t)client, body, blen, 0);
}


/* === Helpers para servidor Agmine Coin (persistencia) === */

/* Verificar si un archivo existe */
int srv_file_exists(const char *path) {
    FILE *f = fopen(path, "r");
    if (f) { fclose(f); return 1; }
    return 0;
}

/* Crear directorio */
void srv_mkdir(const char *path) {
#ifdef _WIN32
    CreateDirectoryA(path, NULL);
#else
    mkdir(path, 0755);
#endif
}

/* Guardar string en archivo */
void srv_save_file(const char *path, const char *data) {
    FILE *f = fopen(path, "w");
    if (!f) return;
    if (data) fputs(data, f);
    fclose(f);
}

/* Cargar archivo como string */
char *srv_load_file(const char *path) {
    static char *buf = NULL;
    FILE *f;
    long sz;
    if (buf) { free(buf); buf = NULL; }
    f = fopen(path, "rb");
    if (!f) return (char*)"";
    fseek(f, 0, SEEK_END);
    sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0 || sz > 10000000) { fclose(f); return (char*)""; }
    buf = (char*)malloc(sz + 1);
    if (!buf) { fclose(f); return (char*)""; }
    fread(buf, 1, sz, f);
    buf[sz] = 0;
    fclose(f);
    return buf;
}

/* Obtener directorio de datos */
char *srv_get_datadir(void) {
    static char path[512] = "data";
    static int init = 0;
    if (!init) {
        srv_mkdir("data");
        init = 1;
    }
    return path;
}


/* === Path completo a accounts.db === */
char *srv_get_accounts_path(void) {
    static char path[512];
    char *dd = srv_get_datadir();
    snprintf(path, sizeof(path), "%s/accounts.db", dd);
    return path;
}


/* === Chat: construir mensaje "usu: msg" === */
char *srv_chat_build(const char *usu, const char *msg) {
    static char buf[4096];
    snprintf(buf, sizeof(buf), "%s: %s", usu ? usu : "", msg ? msg : "");
    return buf;
}


/* === URL decode: %XX -> char, + -> space === */
char *srv_url_decode(const char *s) {
    static char buf[4096];
    int i = 0, j = 0;
    if (!s) { buf[0] = 0; return buf; }
    while (s[i] && j < 4095) {
        if (s[i] == '%' && s[i+1] && s[i+2]) {
            char hex[3] = { s[i+1], s[i+2], 0 };
            buf[j++] = (char)strtol(hex, NULL, 16);
            i += 3;
        } else if (s[i] == '+') {
            buf[j++] = ' ';
            i++;
        } else {
            buf[j++] = s[i++];
        }
    }
    buf[j] = 0;
    return buf;
}


/* === Enviar salto de linea real === */
void srv_send_nl(int client) {
    char nl = '\n';
    send((sock_t)client, &nl, 1, 0);
}


/* === Beep: sonido aleatorio === */
#ifdef _WIN32
#include <windows.h>
#endif
int snd_beep(int freq, int dur) {
#ifdef _WIN32
    Beep(freq, dur);
#else
    /* En Linux/macOS no hay Beep nativo; usar printf BEL */
    printf("\a");
    fflush(stdout);
#endif
    return 0;
}
