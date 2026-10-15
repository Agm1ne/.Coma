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
