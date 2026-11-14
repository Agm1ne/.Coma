/* rt_fs.c — ficheros de .Coma (sesión única, portable, cero dependencias).
   abrir = existe y lee/escribe desde el inicio. crear = vacía (trunca).
   leer = siguiente línea (EOF = ""). escribir = línea + salto.
   Sin handle en el lenguaje a propósito (los vagos no los siguen);
   abrir/crear cierran la anterior sola. Todo error es E105 + exit(1),
   nunca corrupción silenciosa. ¿Permiso denegado? consola de administrador. */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

static FILE *cur = 0;
static char curpath[512] = "";
static int reg = 0;
static int cur_linea = 0;
static char cur_func[128] = "principal";

void coma_donde(int linea, const char *func) {
    cur_linea = linea;
    if (func && func[0]) {
        strncpy(cur_func, func, sizeof(cur_func) - 1);
        cur_func[sizeof(cur_func) - 1] = 0;
    } else {
        strncpy(cur_func, "principal", sizeof(cur_func) - 1);
        cur_func[sizeof(cur_func) - 1] = 0;
    }
}

void coma_einfo(void) {
    printf(" (linea %d, en %s).", cur_linea, cur_func);
}

static void e105(const char *op, const char *p) {
    printf("E105 %s: no se puede (%s). Falta el fichero o permiso denegado (prueba consola de administrador)",
           op, (p && p[0]) ? p : "?");
    coma_einfo();
    printf("\n");
    fflush(stdout);
    exit(1);
}

static void autocierra(void) {
    if (cur) {
        fclose(cur);
        cur = 0;
        curpath[0] = 0;
    }
}

static void regonce(void) {
    if (!reg) {
        atexit(autocierra);
        reg = 1;
    }
}

static void strip_nl(char *b) { b[strcspn(b, "\r\n")] = 0; }

void coma_f_open(const char *path) {
    if (!path || !path[0]) e105("abrir", path);
    regonce();
    autocierra();
    cur = fopen(path, "r+b");
    if (!cur) e105("abrir", path);
    strncpy(curpath, path, sizeof curpath - 1);
    curpath[sizeof curpath - 1] = 0;
}

void coma_f_create(const char *path) {
    if (!path || !path[0]) e105("crear", path);
    regonce();
    autocierra();
    cur = fopen(path, "w+b");
    if (!cur) e105("crear", path);
    strncpy(curpath, path, sizeof curpath - 1);
    curpath[sizeof curpath - 1] = 0;
}

void coma_f_read(char **dst) {
    size_t cap = 256, len = 0;
    char *p = (char *)malloc(cap);
    char chunk[256];
    if (!p) exit(1);
    p[0] = 0;
    if (!cur) e105("leer", "sin abrir");
    for (;;) {
        size_t L;
        int done;
        if (!fgets(chunk, sizeof chunk, cur)) break;
        L = strlen(chunk);
        done = L > 0 && chunk[L - 1] == '\n';
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

void coma_f_write_str(const char *s) {
    if (!cur) e105("escribir", "sin abrir");
    fputs(s ? s : "", cur);
    fputc('\n', cur);
    fflush(cur);
}

void coma_f_write_int(int v) {
    char b[64];
    if (!cur) e105("escribir", "sin abrir");
    snprintf(b, sizeof b, "%d", v);
    fputs(b, cur);
    fputc('\n', cur);
    fflush(cur);
}

void coma_f_write_dbl(double v) {
    char b[64];
    if (!cur) e105("escribir", "sin abrir");
    snprintf(b, sizeof b, "%g", v);
    fputs(b, cur);
    fputc('\n', cur);
    fflush(cur);
}

void coma_f_close(void) { autocierra(); }

void coma_f_delete(const char *path) {
    if (!path || !path[0]) e105("eliminar", path);
    if (cur && strcmp(curpath, path) == 0) autocierra(); /* win no borra abiertos */
    if (remove(path) != 0) e105("eliminar", path);
}

/* --- Memoria directa (bajo tu riesgo): lee el valor al que apunta un asa --- */
int coma_memoria_i32(int64_t h) {
    if (!h) return 0;
    return *(int32_t*)h;
}

double coma_memoria_f64(int64_t h) {
    if (!h) return 0.0;
    return *(double*)h;
}

const char *coma_memoria_str(int64_t h) {
    if (!h) return "";
    return (const char*)h;
}

double coma_seno(double x) {
    return sin(x);
}

double coma_coseno(double x) {
    return cos(x);
}
