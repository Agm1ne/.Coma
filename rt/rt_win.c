/* rt_win.c — runtime .Coma para Windows (todo por carga dinámica: sin .lib extra). */
#include "coma_rt.h"
#include <windows.h>
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

/* --- FIFO 16 para no perder taps entre frames (llena: se queda) --- */
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

static int raw_key(void) {
    int c = _getch();
    if (c == 0 || c == 224) {
        int c2 = _getch();
        if (c2 == 72) return 'w';
        if (c2 == 80) return 's';
        if (c2 == 75) return 'a';
        if (c2 == 77) return 'd';
        return tolower(c2);
    }
    return tolower(c);
}

/* ---------------- consola / teclado / tiempo / pedir ---------------- */
#ifndef ENABLE_QUICK_EDIT_MODE
#define ENABLE_QUICK_EDIT_MODE 0x0040
#endif
#ifndef ENABLE_EXTENDED_FLAGS
#define ENABLE_EXTENDED_FLAGS 0x0080
#endif

void coma_console_init(void) {
    SetConsoleOutputCP(65001);
    SetConsoleCP(65001);
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD mOut = 0;
    if (GetConsoleMode(hOut, &mOut)) SetConsoleMode(hOut, mOut | 4); /* VT */

    HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
    DWORD mIn = 0;
    if (GetConsoleMode(hIn, &mIn)) {
        SetConsoleMode(hIn, (mIn & ~ENABLE_QUICK_EDIT_MODE) | ENABLE_EXTENDED_FLAGS);
    }
}

static int hascon = -1;

int coma_kbhit(void) {
    if (fcount > 0) return 1;
    if (hascon < 0) {
        DWORD m = 0;
        /* Sin consola (tubo/servicio) el fallo de _kbhit cuesta ~20us por
           llamada; se detecta una vez y se ataja a ns. */
        hascon = GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), &m) ? 1 : 0;
    }
    if (!hascon) return 0;
    return _kbhit() ? 1 : 0;
}

int coma_getch(void) {
    int c;
    if (fifo_pop(&c)) return c;
    return raw_key();
}

static unsigned char key_latched[256];

void coma_tick_wait(int ms) {
    ULONGLONG start = GetTickCount64();
    if (ms < 0) ms = 0;
    memset(key_latched, 0, sizeof(key_latched));
    while ((int)(GetTickCount64() - start) < ms) {
        int vk;
        if (_kbhit()) {
            int c = raw_key();
            if (c > 0) fifo_push(c);
        }
        for (vk = 1; vk < 256; vk++) {
            if (GetAsyncKeyState(vk) & 0x8000) {
                key_latched[vk] = 1;
            }
        }
        Sleep(1);
    }
}

int coma_key_down(int vk) {
    if (vk < 0 || vk >= 256) return (GetAsyncKeyState(vk) & 0x8000) ? 1 : 0;
    if (key_latched[vk] || (GetAsyncKeyState(vk) & 0x8000)) {
        return 1;
    }
    return 0;
}

void coma_sleep_ms(int ms) {
    if (ms > 0) Sleep((DWORD)ms);
}

static void strip_nl(char *b) { b[strcspn(b, "\r\n")] = 0; }

void coma_pedir(char **dst) {
    size_t cap = 256, len = 0;
    char *p = (char *)malloc(cap);
    char chunk[256];
    if (!p) exit(1);
    p[0] = 0;
    for (;;) {
        if (!fgets(chunk, sizeof chunk, stdin)) break;
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
    strip_nl(p);
    free(*dst);
    *dst = p;
}

int coma_pedir_int(int *out) {
    char b[256];
    for (;;) {
        if (!fgets(b, sizeof b, stdin)) { *out = 0; return 0; }
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
        if (!fgets(b, sizeof b, stdin)) { *out = 0; return 0; }
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

/* --- Texto y listas en heap (sin topes 256/64) --- */
void coma_str_assign(char **dst, const char *src) {
    size_t n = src ? strlen(src) + 1 : 1;
    char *p = (char *)malloc(n ? n : 1);
    if (!p) exit(1);
    if (src) memcpy(p, src, n);
    else p[0] = 0;
    free(*dst);
    *dst = p;
}

void coma_str_free(char *p) { free(p); }

static void e101(void) {
    printf("E101 indice fuera de rango\n");
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

/* ---------------- XInput por carga dinámica ---------------- */
typedef struct { WORD wButtons; BYTE bLT, bRT; SHORT sLX, sLY, sRX, sRY; } XGpad;
typedef struct { DWORD pkt; XGpad g; } XState;
typedef DWORD (WINAPI *XGetFn)(DWORD, XState *);
static XGetFn xget = 0;
static int xtried = 0;
#define XB_DU 0x0001
#define XB_DD 0x0002
#define XB_DL 0x0004
#define XB_DR 0x0008
#define XB_ST 0x0010
#define XB_BK 0x0020
#define XB_A 0x1000
#define XB_B 0x2000
#define XB_X 0x4000
#define XB_Y 0x8000
#define XB_LB 0x0100

static void xinit(void) {
    int i;
    const char *dlls[] = {"xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll", 0};
    if (xtried) return;
    xtried = 1;
    for (i = 0; dlls[i]; i++) {
        HMODULE h = LoadLibraryA(dlls[i]);
        if (!h) continue;
        xget = (XGetFn)GetProcAddress(h, "XInputGetState");
        if (xget) return;
    }
}

/* ---------------- winmm por carga dinámica (guitarras/adaptadores) ---------------- */
typedef struct {
    DWORD size, flags, x, y, z, r, u, v, buttons, nbut, pov, r1, r2;
} JoyEx;
typedef UINT (WINAPI *JoyFn)(UINT, JoyEx *);
static JoyFn jget = 0;
static int jtried = 0;
#define JOY_ALL 0xFF
#define POV_OFF 0xFFFF

static void jinit(void) {
    if (jtried) return;
    jtried = 1;
    HMODULE h = LoadLibraryA("winmm.dll");
    if (h) jget = (JoyFn)GetProcAddress(h, "joyGetPosEx");
}

static int xcode(XState *s, int code) {
    WORD b = s->g.wButtons;
    switch (code) {
    case COMA_PAD_A: return (b & XB_A) != 0;
    case COMA_PAD_B: return (b & XB_B) != 0;
    case COMA_PAD_X: return (b & XB_X) != 0;
    case COMA_PAD_Y: return (b & XB_Y) != 0;
    case COMA_PAD_LB: return (b & XB_LB) != 0;
    case COMA_PAD_RB: return (b & 0x0200) != 0;
    case COMA_PAD_BACK: return (b & XB_BK) != 0;
    case COMA_PAD_START: return (b & XB_ST) != 0;
    case COMA_PAD_UP: return (b & XB_DU) != 0;
    case COMA_PAD_DOWN: return (b & XB_DD) != 0;
    case COMA_PAD_LEFT: return (b & XB_DL) != 0;
    case COMA_PAD_RIGHT: return (b & XB_DR) != 0;
    case COMA_FRET_GREEN: return (b & XB_A) != 0;
    case COMA_FRET_RED: return (b & XB_B) != 0;
    case COMA_FRET_YELLOW: return (b & XB_Y) != 0;
    case COMA_FRET_BLUE: return (b & XB_X) != 0;
    case COMA_FRET_ORANGE: return (b & XB_LB) != 0;
    case COMA_STRUM_UP: return (b & XB_DU) != 0;
    case COMA_STRUM_DOWN: return (b & XB_DD) != 0;
    case COMA_WHAMMY: return s->g.sRY > 8000 || s->g.sRY < -8000;
    default: return 0;
    }
}

static int jcode(JoyEx *j, int code) {
    DWORD b = j->buttons;
    switch (code) {
    case COMA_FRET_GREEN: return (b & 1) != 0;
    case COMA_FRET_RED: return (b & 2) != 0;
    case COMA_FRET_YELLOW: return (b & 4) != 0;
    case COMA_FRET_BLUE: return (b & 8) != 0;
    case COMA_FRET_ORANGE: return (b & 16) != 0;
    case COMA_PAD_START: return (b & 512) != 0;
    case COMA_PAD_BACK: return (b & 256) != 0;
    case COMA_STRUM_UP: return (j->pov != POV_OFF && j->pov <= 4500) || (b & 64) != 0;
    case COMA_STRUM_DOWN:
        return (j->pov != POV_OFF && j->pov >= 13500 && j->pov <= 22500) || (b & 128) != 0;
    case COMA_PAD_UP: return j->pov != POV_OFF && j->pov <= 4500;
    case COMA_PAD_DOWN: return j->pov != POV_OFF && j->pov >= 13500 && j->pov <= 22500;
    case COMA_PAD_LEFT:
        return j->pov != POV_OFF && j->pov >= 22500 && j->pov <= 31500;
    case COMA_PAD_RIGHT:
        return j->pov != POV_OFF && j->pov >= 4500 && j->pov <= 13500;
    case COMA_WHAMMY: {
        int z = (int)j->z - 32768;
        return z > 16000 || z < -16000;
    }
    default: return 0;
    }
}

int coma_pad_count(void) {
    int n = 0, i;
    XState s;
    xinit();
    jinit();
    for (i = 0; i < 4; i++) {
        if ((xget && xget((DWORD)i, &s) == 0)) { n++; continue; }
        if (jget) {
            JoyEx j;
            memset(&j, 0, sizeof j);
            j.size = sizeof j;
            j.flags = JOY_ALL;
            if (jget((UINT)i, &j) == 0) n++;
        }
    }
    return n;
}

int coma_pad_down(int pad, int code) {
    XState s;
    xinit();
    jinit();
    if (pad >= 0 && pad < 4 && xget && xget((DWORD)pad, &s) == 0)
        return xcode(&s, code);
    if (jget && pad >= 0 && pad < 16) {
        JoyEx j;
        memset(&j, 0, sizeof j);
        j.size = sizeof j;
        j.flags = JOY_ALL;
        if (jget((UINT)pad, &j) == 0)
            return jcode(&j, code);
    }
    return 0;
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

/* ---------------- presets del sistema ---------------- */
typedef struct {
    unsigned long infoSize, major, minor, build, plat;
    wchar_t csd[128];
} MiniVer;
typedef long (WINAPI *RtlVerFn)(MiniVer *);

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
        const char *u = getenv("USERNAME");
        if (!u) u = getenv("USER");
        strncpy(b[2], u ? u : "?", sizeof b[2] - 1);
        b[2][sizeof b[2] - 1] = 0;
        return b[2];
    }
    case SYS_SISTEMA:
        return "Windows";
    case SYS_VERSION: {
        static RtlVerFn fn = 0;
        static int probado = 0;
        if (!probado) {
            HMODULE h;
            probado = 1;
            h = LoadLibraryA("ntdll.dll");
            if (h) fn = (RtlVerFn)GetProcAddress(h, "RtlGetVersion");
        }
        if (fn) {
            MiniVer v;
            memset(&v, 0, sizeof v);
            v.infoSize = sizeof v;
            if (fn(&v) == 0) {
                snprintf(b[4], sizeof b[4], "%lu.%lu.%lu",
                         v.major, v.minor, v.build);
                return b[4];
            }
        }
        return "?";
    }
    case SYS_CARPETA:
        if (GetCurrentDirectoryA((DWORD)sizeof b[5], b[5]) == 0)
            return "?";
        return b[5];
    default:
        return "";
    }
}

int coma_stricmp(const char *a, const char *b) {
    if (!a) a = "";
    if (!b) b = "";
    return _stricmp(a, b);
}
