/* rt_unix.c — runtime .Coma para Linux y macOS (solo libc + termios).
   Teclado: raw + select + flechas ESC[A-D -> wasd. Sin consola (tubo):
   todo neutro, pedir sigue leyendo por fgets.
   Tecla "x": latch de 300 ms (el terminal repite al mantener: los
   mantenidos funcionan; en Windows es estado real — ver coma_rt.h).
   Mandos: evdev en Linux (grupo `input`); macOS siempre 0 (falta IOKit). */
#define _DEFAULT_SOURCE
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/select.h>
#include <sys/time.h>
#include <time.h>
#include <locale.h>
#include <ctype.h>
#include <errno.h>
#include <sys/utsname.h>
#ifdef __linux__
#include <linux/input.h>
#include <sys/ioctl.h>
#endif

static struct termios g_orig;
static int g_raw = 0, g_istty = 0;

static void raw_off(void) {
    if (g_raw) tcsetattr(STDIN_FILENO, TCSANOW, &g_orig);
}

void coma_console_init(void) {
    setlocale(LC_ALL, "");
    g_istty = isatty(STDIN_FILENO);
    if (g_istty && tcgetattr(STDIN_FILENO, &g_orig) == 0) {
        struct termios r = g_orig;
        r.c_lflag &= (tcflag_t) ~(ICANON | ECHO);
        r.c_cc[VMIN] = 0;
        r.c_cc[VTIME] = 0;
        if (tcsetattr(STDIN_FILENO, TCSANOW, &r) == 0) {
            g_raw = 1;
            atexit(raw_off);
        }
    }
}

#define FIFO_N 16
static int fifo[FIFO_N];
static int fhead = 0, ftail = 0, fcount = 0;
static void fifo_push(int c) {
    if (fcount < FIFO_N) {
        fifo[ftail] = c;
        ftail = (ftail + 1) % FIFO_N;
        fcount++;
    }
}
static int fifo_pop(int *c) {
    if (!fcount) return 0;
    *c = fifo[fhead];
    fhead = (fhead + 1) % FIFO_N;
    fcount--;
    return 1;
}

int coma_kbhit(void) {
    fd_set f;
    struct timeval t;
    if (fcount > 0) return 1;
    if (!g_istty) return 0;
    FD_ZERO(&f);
    FD_SET(STDIN_FILENO, &f);
    t.tv_sec = 0;
    t.tv_usec = 0;
    return select(STDIN_FILENO + 1, &f, 0, 0, &t) > 0 ? 1 : 0;
}

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int g_lastkey = 0;
static long long g_lastms = 0;
static int g_pushback = -1;

static int rd_byte(void) {
    unsigned char b;
    ssize_t n = read(STDIN_FILENO, &b, 1);
    if (n != 1) return -1;
    return (int)b;
}

static int raw_key(void) {
    int c;
    if (g_pushback >= 0) {
        c = g_pushback;
        g_pushback = -1;
    } else {
        c = rd_byte();
        if (c < 0) return 0;
    }
    if (c == 27) { /* ESC [ A/B/C/D */
        int b2 = rd_byte();
        if (b2 != 91) {
            if (b2 >= 0) g_pushback = b2;
            return 27;
        }
        int b3 = rd_byte();
        if (b3 < 0) return 27;
        if (b3 == 65) c = 'w';
        else if (b3 == 66) c = 's';
        else if (b3 == 67) c = 'd';
        else if (b3 == 68) c = 'a';
        else {
            g_pushback = b3;
            return 27;
        }
    } else if (c >= 'A' && c <= 'Z') {
        c = tolower(c);
    }
    return c;
}

static void note_key(int c) {
    if (c > 0) {
        g_lastkey = c;
        g_lastms = now_ms();
    }
}

int coma_getch(void) {
    int c;
    if (fifo_pop(&c)) {
        note_key(c);
        return c;
    }
    c = raw_key();
    note_key(c);
    return c;
}

static void ms_sleep(int ms) {
    struct timespec t;
    if (ms <= 0) return;
    t.tv_sec = ms / 1000;
    t.tv_nsec = (long)(ms % 1000) * 1000000L;
    nanosleep(&t, 0);
}

void coma_tick_wait(int ms) {
    int i;
    if (ms < 0) ms = 0;
    for (i = 0; i < ms; i++) {
        if (coma_kbhit()) {
            int c = raw_key();
            if (c > 0) {
                fifo_push(c);
                note_key(c);
            }
        }
        ms_sleep(1);
    }
}

#ifdef __linux__
/* Adelanto (definido junto a evdev): -1 sin teclados, 0/1 estado real. */
static int kbd_state(int vk, int want);
#endif

int coma_key_down(int vk) {
    int want = -1;
    if (vk >= 'a' && vk <= 'z') want = vk;
    else if (vk >= 'A' && vk <= 'Z') want = tolower(vk);
    else if (vk == 37) want = 'a';
    else if (vk == 38) want = 'w';
    else if (vk == 39) want = 'd';
    else if (vk == 40) want = 's';
    else return 0;
#ifdef __linux__
    /* Estado real por evdev si hay teclado visible; si no, latch. */
    {
        int r = kbd_state(vk, want);
        if (r >= 0) return r;
    }
#endif
    if (!g_istty) return 0;
    return (g_lastkey == want && now_ms() - g_lastms < 300) ? 1 : 0;
}

void coma_sleep_ms(int ms) { ms_sleep(ms); }

static void strip_nl(char *b) { b[strcspn(b, "\r\n")] = 0; }

static void raw_temp_off(void) {
    if (g_raw) tcsetattr(STDIN_FILENO, TCSANOW, &g_orig);
}

static void raw_temp_on(void) {
    if (g_raw) {
        struct termios r = g_orig;
        r.c_lflag &= (tcflag_t) ~(ICANON | ECHO);
        r.c_cc[VMIN] = 0;
        r.c_cc[VTIME] = 0;
        tcsetattr(STDIN_FILENO, TCSANOW, &r);
    }
}

void coma_pedir(char **dst) {
    size_t cap = 256, len = 0;
    char *p = (char *)malloc(cap);
    char chunk[256];
    if (!p) exit(1);
    p[0] = 0;
    raw_temp_off(); /* cocido para linea */
    for (;;) {
        if (!fgets(chunk, sizeof chunk, stdin)) break;
        {
            size_t L = strlen(chunk);
            int done = L > 0 && chunk[L - 1] == '\n';
            while (len + L + 1 > cap) cap *= 2;
            {
                char *np = (char *)realloc(p, cap);
                if (!np) exit(1);
                p = np;
            }
            memcpy(p + len, chunk, L + 1);
            len += L;
            if (done) break;
        }
    }
    raw_temp_on();
    strip_nl(p);
    if (*dst) free(*dst);
    *dst = p;
}

int coma_pedir_int(int *out) {
    char b[256];
    for (;;) {
        raw_temp_off();
        if (!fgets(b, sizeof b, stdin)) {
            raw_temp_on();
            *out = 0;
            return 0;
        }
        raw_temp_on();
        strip_nl(b);
        if (b[0] == 0) { *out = 0; return 1; }
        {
            char *e = 0;
            long v = strtol(b, &e, 10);
            if (e && *e == 0) { *out = (int)v; return 1; }
        }
        printf("E103 espero un numero.\n");
        fflush(stdout);
    }
}

int coma_pedir_dbl(double *out) {
    char b[256];
    for (;;) {
        raw_temp_off();
        if (!fgets(b, sizeof b, stdin)) {
            raw_temp_on();
            *out = 0;
            return 0;
        }
        raw_temp_on();
        strip_nl(b);
        if (b[0] == 0) { *out = 0; return 1; }
        {
            char *e = 0;
            char *c;
            double v;
            for (c = b; *c; c++)
                if (*c == ',') *c = '.'; /* coma decimal -> punto C */
            v = strtod(b, &e);
            if (e && *e == 0) { *out = v; return 1; }
        }
        printf("E103 espero un numero.\n");
        fflush(stdout);
    }
}

void coma_str_assign(char **dst, const char *src) {
    size_t n = src ? strlen(src) + 1 : 1;
    char *p = (char *)malloc(n ? n : 1);
    if (!p) exit(1);
    if (src) memcpy(p, src, n);
    else p[0] = 0;
    if (*dst) free(*dst);
    *dst = p;
}

void coma_str_free(char *p) { free(p); }

static void e101(void) {
    printf("E101 indice fuera de rango");
    coma_einfo();
    printf("\n");
    fflush(stdout);
    exit(1);
}

static void lgrow(CList *h, int need) {
    int nc;
    int *nd;
    if (h->c >= need) return;
    nc = h->c ? h->c * 2 : 8;
    while (nc < need) nc *= 2;
    nd = (int *)realloc(h->d, (size_t)nc * sizeof(int));
    if (!nd) exit(1);
    h->d = nd;
    h->c = nc;
}

int coma_list_len(CList *h) { return h ? h->n : 0; }

int coma_list_get(CList *h, int i) {
    if (!h || i < 0 || i >= h->n) e101();
    return h->d[i];
}

void coma_list_set(CList *h, int i, int v) {
    if (!h || i < 0 || i >= h->n) e101();
    h->d[i] = v;
}

void coma_list_add(CList *h, int v) {
    if (!h) e101();
    lgrow(h, h->n + 1);
    h->d[h->n++] = v;
}

void coma_list_rmval(CList *h, int v) {
    int i, j;
    if (!h) e101();
    for (i = 0; i < h->n; i++)
        if (h->d[i] == v) {
            for (j = i; j + 1 < h->n; j++) h->d[j] = h->d[j + 1];
            h->n--;
            return;
        }
}

void coma_list_rmat(CList *h, int i) {
    int j;
    if (!h || i < 0 || i >= h->n) e101();
    for (j = i; j + 1 < h->n; j++) h->d[j] = h->d[j + 1];
    h->n--;
}

void coma_list_reset(CList *h) { if (h) h->n = 0; }

void coma_list_copy(CList *dst, CList *src) {
    if (!dst) return;
    if (!src) {
        dst->n = 0;
        return;
    }
    if (src->n > 0) {
        lgrow(dst, src->n);
        memcpy(dst->d, src->d, (size_t)src->n * sizeof(int));
    }
    dst->n = src->n;
}

void coma_list_free(CList *h) {
    if (!h) return;
    free(h->d);
    h->d = 0;
    h->n = 0;
    h->c = 0;
}

/* ---------------- listas de texto (copia profunda, sin topes) ---------------- */
static char *xdup(const char *s) {
    size_t n = s ? strlen(s) + 1 : 1;
    char *p = (char *)malloc(n ? n : 1);
    if (!p) exit(1);
    if (s) memcpy(p, s, n);
    else p[0] = 0;
    return p;
}

static void sgrow(CListStr *h, int need) {
    int nc;
    char **nd;
    if (h->c >= need) return;
    nc = h->c ? h->c * 2 : 8;
    while (nc < need) nc *= 2;
    nd = (char **)realloc(h->d, (size_t)nc * sizeof(char *));
    if (!nd) exit(1);
    h->d = nd;
    h->c = nc;
}

int coma_slist_len(CListStr *h) { return h ? h->n : 0; }

const char *coma_slist_get(CListStr *h, int i) {
    if (!h || i < 0 || i >= h->n) e101();
    return h->d[i] ? h->d[i] : "";
}

void coma_slist_set(CListStr *h, int i, const char *v) {
    if (!h || i < 0 || i >= h->n) e101();
    free(h->d[i]);
    h->d[i] = xdup(v);
}

void coma_slist_add(CListStr *h, const char *v) {
    if (!h) e101();
    sgrow(h, h->n + 1);
    h->d[h->n++] = xdup(v);
}

void coma_slist_rmval(CListStr *h, const char *v) {
    int i, j;
    if (!h) e101();
    if (!v) v = "";
    for (i = 0; i < h->n; i++)
        if (strcmp(h->d[i] ? h->d[i] : "", v) == 0) {
            free(h->d[i]);
            for (j = i; j + 1 < h->n; j++) h->d[j] = h->d[j + 1];
            h->n--;
            return;
        }
}

void coma_slist_rmat(CListStr *h, int i) {
    int j;
    if (!h || i < 0 || i >= h->n) e101();
    free(h->d[i]);
    for (j = i; j + 1 < h->n; j++) h->d[j] = h->d[j + 1];
    h->n--;
}

void coma_slist_reset(CListStr *h) {
    int i;
    if (!h) return;
    for (i = 0; i < h->n; i++) free(h->d[i]);
    h->n = 0;
}

void coma_slist_copy(CListStr *dst, CListStr *src) {
    int i;
    if (!dst || dst == src) return;
    coma_slist_reset(dst);
    if (!src) return;
    if (src->n > 0) {
        sgrow(dst, src->n);
        for (i = 0; i < src->n; i++) dst->d[i] = xdup(src->d[i]);
    }
    dst->n = src ? src->n : 0;
}

void coma_slist_free(CListStr *h) {
    if (!h) return;
    coma_slist_reset(h);
    free(h->d);
    h->d = 0;
    h->c = 0;
}

/* ---------------- listas de listas de enteros (copia profunda) ---------------- */
static void qgrow(CListList *h, int need) {
    int nc;
    CList *nd;
    if (h->c >= need) return;
    nc = h->c ? h->c * 2 : 8;
    while (nc < need) nc *= 2;
    nd = (CList *)realloc(h->d, (size_t)nc * sizeof(CList));
    if (!nd) exit(1);
    h->d = nd;
    h->c = nc;
}

static void qdeepdup(CList *dst, const CList *src) {
    dst->n = src->n;
    dst->c = 0;
    dst->d = 0;
    if (src->n > 0) {
        dst->d = (int *)malloc((size_t)src->n * sizeof(int));
        if (!dst->d) exit(1);
        memcpy(dst->d, src->d, (size_t)src->n * sizeof(int));
        dst->c = src->n;
    }
}

static int qsame(const CList *a, const CList *b) {
    int i;
    if (a->n != b->n) return 0;
    for (i = 0; i < a->n; i++)
        if (a->d[i] != b->d[i]) return 0;
    return 1;
}

int coma_llist_len(CListList *h) { return h ? h->n : 0; }

void coma_llist_get(CListList *h, int i, CList *out) {
    if (!h || !out || i < 0 || i >= h->n) e101();
    *out = h->d[i];
}

void coma_llist_set(CListList *h, int i, CList *v) {
    if (!h || !v || i < 0 || i >= h->n) e101();
    free(h->d[i].d);
    qdeepdup(&h->d[i], v);
}

void coma_llist_add(CListList *h, CList *v) {
    if (!h || !v) e101();
    qgrow(h, h->n + 1);
    qdeepdup(&h->d[h->n++], v);
}

void coma_llist_rmval(CListList *h, CList *v) {
    int i, j;
    if (!h || !v) e101();
    for (i = 0; i < h->n; i++)
        if (qsame(&h->d[i], v)) {
            free(h->d[i].d);
            for (j = i; j + 1 < h->n; j++) h->d[j] = h->d[j + 1];
            h->n--;
            return;
        }
}

void coma_llist_rmat(CListList *h, int i) {
    int j;
    if (!h || i < 0 || i >= h->n) e101();
    free(h->d[i].d);
    for (j = i; j + 1 < h->n; j++) h->d[j] = h->d[j + 1];
    h->n--;
}

void coma_llist_reset(CListList *h) {
    int i;
    if (!h) return;
    for (i = 0; i < h->n; i++) free(h->d[i].d);
    h->n = 0;
}

void coma_llist_copy(CListList *dst, CListList *src) {
    int i;
    if (!dst || dst == src) return;
    coma_llist_reset(dst);
    if (!src) return;
    if (src->n > 0) {
        qgrow(dst, src->n);
        for (i = 0; i < src->n; i++) qdeepdup(&dst->d[i], &src->d[i]);
    }
    dst->n = src ? src->n : 0;
}

void coma_llist_free(CListList *h) {
    if (!h) return;
    coma_llist_reset(h);
    free(h->d);
    h->d = 0;
    h->c = 0;
}

/* ---------------- listas de registros (filas de enteros, ancho fijo) ---------------- */
void coma_rlist_reset(CRecList *h, int ncols) {
    if (!h) return;
    free(h->d);
    h->d = 0;
    h->nrows = 0;
    h->ncols = ncols > 0 ? ncols : 0;
}

void coma_rlist_addrow(CRecList *h) {
    int nc, i;
    int *nd;
    if (!h || h->ncols <= 0) e101();
    nc = (h->nrows + 1) * h->ncols;
    nd = (int *)realloc(h->d, (size_t)nc * sizeof(int));
    if (!nd) exit(1);
    h->d = nd;
    for (i = 0; i < h->ncols; i++) h->d[h->nrows * h->ncols + i] = 0;
    h->nrows++;
}

int coma_rlist_len(CRecList *h) { return h ? h->nrows : 0; }

int coma_rlist_get(CRecList *h, int r, int c) {
    if (!h || r < 0 || r >= h->nrows || c < 0 || c >= h->ncols) e101();
    return h->d[r * h->ncols + c];
}

void coma_rlist_set(CRecList *h, int r, int c, int v) {
    if (!h || r < 0 || r >= h->nrows || c < 0 || c >= h->ncols) e101();
    h->d[r * h->ncols + c] = v;
}

void coma_rlist_copy(CRecList *dst, CRecList *src) {
    size_t n;
    if (!dst || dst == src) return;
    free(dst->d);
    dst->d = 0;
    dst->nrows = 0;
    dst->ncols = 0;
    if (!src || src->nrows <= 0 || src->ncols <= 0) return;
    n = (size_t)src->nrows * (size_t)src->ncols;
    dst->d = (int *)malloc(n * sizeof(int));
    if (!dst->d) exit(1);
    memcpy(dst->d, src->d, n * sizeof(int));
    dst->nrows = src->nrows;
    dst->ncols = src->ncols;
}

void coma_rlist_free(CRecList *h) {
    if (!h) return;
    free(h->d);
    h->d = 0;
    h->nrows = 0;
    h->ncols = 0;
}

/* ---------------- mandos por evdev (solo Linux) ---------------- */
#ifdef __linux__
#define MAXP 4
#define MAXK 4
static int efd[MAXP];
static int npad = -1;
static unsigned long pressed[MAXP][8];
static int absv[MAXP][ABS_MAX + 1];
static int absmin[MAXP][ABS_MAX + 1];
static int absmax[MAXP][ABS_MAX + 1];
static int abshas[MAXP][ABS_MAX + 1];
/* Teclados evdev: estado REAL de tecla mantenida (si hay permiso). */
static int kfd[MAXK];
static int nkbd = -1;
static unsigned long kbd[MAXK][8];

static int has_bit(unsigned long *b, int code) {
    return (b[code / 64] >> (code % 64)) & 1UL;
}

static void ev_open(void) {
    int i, k;
    npad = 0;
    nkbd = 0;
    for (i = 0; i < 32 && (npad < MAXP || nkbd < MAXK); i++) {
        char p[64];
        int fd;
        unsigned long b[8];
        snprintf(p, sizeof p, "/dev/input/event%d", i);
        fd = open(p, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;
        memset(b, 0, sizeof b);
        if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof b), b) < 0) {
            close(fd);
            continue;
        }
        for (k = 0; k < 8 && !b[k]; k++) {
        }
        if (k == 8) {
            close(fd);
            continue;
        }
        /* Teclado = KEY_A + KEY_ENTER sin botones de ratón. */
        if (nkbd < MAXK && has_bit(b, KEY_A) && has_bit(b, KEY_ENTER) &&
            !has_bit(b, BTN_MOUSE)) {
            memset(kbd[nkbd], 0, sizeof kbd[nkbd]);
            kfd[nkbd] = fd;
            nkbd++;
            continue;
        }
        if (npad >= MAXP) {
            close(fd);
            continue;
        }
        memset(pressed[npad], 0, sizeof pressed[npad]);
        memset(abshas[npad], 0, sizeof abshas[npad]);
        efd[npad] = fd;
        npad++;
    }
}

static void kbd_poll(void) {
    int p;
    struct input_event ev;
    if (nkbd < 0) ev_open();
    for (p = 0; p < nkbd; p++) {
        while (read(kfd[p], &ev, sizeof ev) == (ssize_t)sizeof ev) {
            if (ev.type == EV_KEY && ev.code >= 0 && ev.code < 512) {
                if (ev.value) kbd[p][ev.code / 64] |= 1UL << (ev.code % 64);
                else kbd[p][ev.code / 64] &= ~(1UL << (ev.code % 64));
            }
        }
    }
}

/* ASCII -> código evdev (distribución qwerty de códigos, no letras). */
static int ascii_evdev(int c) {
    static const char row1[] = "qwertyuiop";
    static const char row2[] = "asdfghjkl";
    static const char row3[] = "zxcvbnm";
    int i;
    for (i = 0; i < 10; i++)
        if (row1[i] == c) return KEY_Q + i;
    for (i = 0; i < 9; i++)
        if (row2[i] == c) return KEY_A + i;
    for (i = 0; i < 7; i++)
        if (row3[i] == c) return KEY_Z + i;
    return -1;
}

static int kbd_is(int code) {
    int p;
    if (code < 0 || code >= 512) return 0;
    for (p = 0; p < nkbd; p++)
        if (has_bit(kbd[p], code)) return 1;
    return 0;
}

static int kbd_state(int vk, int want) {
    int code = -1;
    kbd_poll();
    if (nkbd <= 0) return -1;
    if (want == 'a' && vk == 37) code = KEY_LEFT;
    else if (want == 'w' && vk == 38) code = KEY_UP;
    else if (want == 'd' && vk == 39) code = KEY_RIGHT;
    else if (want == 's' && vk == 40) code = KEY_DOWN;
    else code = ascii_evdev(want);
    if (code < 0) return -1;
    return kbd_is(code);
}

static void ev_poll(void) {
    int p, i;
    struct input_event ev;
    if (npad < 0) ev_open();
    for (p = 0; p < npad; p++) {
        while (read(efd[p], &ev, sizeof ev) == (ssize_t)sizeof ev) {
            if (ev.type == EV_KEY && ev.code < 512) {
                if (ev.value) pressed[p][ev.code / 64] |= 1UL << (ev.code % 64);
                else pressed[p][ev.code / 64] &= ~(1UL << (ev.code % 64));
            } else if (ev.type == EV_ABS && ev.code <= ABS_MAX) {
                absv[p][ev.code] = ev.value;
            }
        }
        for (i = 0; i <= ABS_MAX; i++) {
            struct input_absinfo ai;
            if (!abshas[p][i] && ioctl(efd[p], EVIOCGABS(i), &ai) == 0) {
                absmin[p][i] = ai.minimum;
                absmax[p][i] = ai.maximum;
                abshas[p][i] = 1;
            }
        }
    }
}

static int ev_is(int p, int code) {
    if (p < 0 || p >= npad || code < 0 || code >= 512) return 0;
    return (pressed[p][code / 64] >> (code % 64)) & 1UL;
}

static int ev_abs_mid(int p, int code) {
    if (p < 0 || p >= npad || code < 0 || code > ABS_MAX || !abshas[p][code])
        return 0;
    return (absmin[p][code] + absmax[p][code]) / 2;
}

static int ev_abs_rng(int p, int code) {
    if (p < 0 || p >= npad || code < 0 || code > ABS_MAX || !abshas[p][code])
        return 0;
    return absmax[p][code] - absmin[p][code];
}

static int ev_moved(int p, int code) {
    int r, d;
    if (p < 0 || p >= npad || code < 0 || code > ABS_MAX || !abshas[p][code])
        return 0;
    r = ev_abs_rng(p, code);
    if (r <= 0) return 0;
    d = absv[p][code] - ev_abs_mid(p, code);
    if (d < 0) d = -d;
    return d > r / 4;
}

static int evpad(int p, int code) {
    switch (code) {
    case COMA_PAD_A: return ev_is(p, BTN_SOUTH) || ev_is(p, BTN_A);
    case COMA_PAD_B: return ev_is(p, BTN_EAST) || ev_is(p, BTN_B);
    case COMA_PAD_X: return ev_is(p, BTN_NORTH) || ev_is(p, BTN_X);
    case COMA_PAD_Y: return ev_is(p, BTN_WEST) || ev_is(p, BTN_Y);
    case COMA_PAD_LB: return ev_is(p, BTN_TL);
    case COMA_PAD_RB: return ev_is(p, BTN_TR);
    case COMA_PAD_BACK: return ev_is(p, BTN_SELECT) || ev_is(p, BTN_8);
    case COMA_PAD_START: return ev_is(p, BTN_START) || ev_is(p, BTN_7);
    case COMA_PAD_LSTICK: return ev_is(p, BTN_THUMBL);
    case COMA_PAD_RSTICK: return ev_is(p, BTN_THUMBR);
    case COMA_PAD_UP:
        return ev_is(p, BTN_DPAD_UP) || absv[p][ABS_HAT0Y] < 0;
    case COMA_PAD_DOWN:
        return ev_is(p, BTN_DPAD_DOWN) || absv[p][ABS_HAT0Y] > 0;
    case COMA_PAD_LEFT:
        return ev_is(p, BTN_DPAD_LEFT) || absv[p][ABS_HAT0X] < 0;
    case COMA_PAD_RIGHT:
        return ev_is(p, BTN_DPAD_RIGHT) || absv[p][ABS_HAT0X] > 0;
    case COMA_FRET_GREEN:
        return ev_is(p, BTN_0) || ev_is(p, BTN_SOUTH);
    case COMA_FRET_RED: return ev_is(p, BTN_1) || ev_is(p, BTN_EAST);
    case COMA_FRET_YELLOW: return ev_is(p, BTN_2) || ev_is(p, BTN_NORTH);
    case COMA_FRET_BLUE: return ev_is(p, BTN_3) || ev_is(p, BTN_WEST);
    case COMA_FRET_ORANGE: return ev_is(p, BTN_4) || ev_is(p, BTN_TL);
    case COMA_STRUM_UP: return ev_is(p, BTN_6);
    case COMA_STRUM_DOWN: return ev_is(p, BTN_5);
    case COMA_WHAMMY: return ev_moved(p, ABS_RZ) || ev_moved(p, ABS_Z);
    default: return 0;
    }
}
#endif

int coma_pad_count(void) {
#ifdef __linux__
    ev_poll();
    return npad < 0 ? 0 : npad;
#else
    return 0;
#endif
}

int coma_pad_down(int pad, int code) {
#ifdef __linux__
    ev_poll();
    if (pad < 0 || pad >= npad) return 0;
    return evpad(pad, code);
#else
    (void)pad;
    (void)code;
    return 0;
#endif
}

const char *coma_pad_last(int pad) {
    static char last[32] = "";
    static const struct { int code; const char *name; } tab[] = {
        {COMA_FRET_GREEN, "verde"}, {COMA_FRET_RED, "roja"},
        {COMA_FRET_YELLOW, "amarilla"}, {COMA_FRET_BLUE, "azul"},
        {COMA_FRET_ORANGE, "naranja"},
        {COMA_STRUM_UP, "rasgueo arriba"}, {COMA_STRUM_DOWN, "rasgueo abajo"},
        {COMA_PAD_A, "a"}, {COMA_PAD_B, "b"}, {COMA_PAD_X, "x"}, {COMA_PAD_Y, "y"},
        {COMA_PAD_START, "start"}, {COMA_PAD_BACK, "select"},
        {COMA_PAD_UP, "arriba"}, {COMA_PAD_DOWN, "abajo"},
        {COMA_PAD_LEFT, "izquierda"}, {COMA_PAD_RIGHT, "derecha"},
        {COMA_WHAMMY, "palanca"}, {0, 0}
    };
    int i;
    for (i = 0; tab[i].name; i++)
        if (coma_pad_down(pad, tab[i].code)) {
            strncpy(last, tab[i].name, sizeof last - 1);
            last[sizeof last - 1] = 0;
            return last;
        }
    return last;
}

/* ---------------- presets del sistema (POSIX) ---------------- */
const char *coma_sys_info(int which) {
    static char b[6][128];
    time_t tt;
    struct tm *lt;
    if (which < 1 || which > 6) return "";
    time(&tt);
    lt = localtime(&tt);
    switch (which) {
    case SYS_HORA:
        snprintf(b[0], sizeof b[0], "%02d:%02d:%02d",
                 lt ? lt->tm_hour : 0, lt ? lt->tm_min : 0, lt ? lt->tm_sec : 0);
        return b[0];
    case SYS_FECHA:
        snprintf(b[1], sizeof b[1], "%04d-%02d-%02d",
                 lt ? lt->tm_year + 1900 : 0, lt ? lt->tm_mon + 1 : 0,
                 lt ? lt->tm_mday : 0);
        return b[1];
    case SYS_USUARIO: {
        const char *u = getenv("USER");
        if (!u) u = getenv("LOGNAME");
        if (!u) u = getenv("USERNAME");
        strncpy(b[2], u ? u : "?", sizeof b[2] - 1);
        b[2][sizeof b[2] - 1] = 0;
        return b[2];
    }
    case SYS_SISTEMA:
#ifdef __APPLE__
        return "macOS";
#else
        return "Linux";
#endif
    case SYS_VERSION: {
#ifdef __linux__
        struct utsname un;
        if (uname(&un) == 0) {
            strncpy(b[4], un.release, sizeof b[4] - 1);
            b[4][sizeof b[4] - 1] = 0;
            return b[4];
        }
#endif
        return "?";
    }
    case SYS_CARPETA:
        if (getcwd(b[5], sizeof b[5]) == 0)
            return "?";
        return b[5];
    default:
        return "";
    }
}

int coma_stricmp(const char *a, const char *b) {
    if (!a) a = "";
    if (!b) b = "";
    return strcasecmp(a, b);
}
