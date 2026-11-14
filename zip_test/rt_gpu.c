/* rt_gpu.c - GPU por single-source CPU (sin DirectX) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "coma_rt.h"

#ifndef GPU_MAX
#define GPU_MAX (1 << 20)
#endif

static int g_started = 0;
static int g_has_prog = 0;
static char g_hlsl[4096];

static void g106(const char* op, const char* det) {
    printf("E106 gpu %s: no se puede (%s)", op, det ? det : "?");
    coma_einfo();
    printf("\n");
    fflush(stdout);
    exit(1);
}

void coma_gpu_iniciar(void) {
    if (g_started) return;
    g_started = 1;
    g_has_prog = 0;
    g_hlsl[0] = 0;
}

void coma_gpu_programa(const char* hlsl) {
    if (!g_started) g106("programa", "primero gpu iniciar.");
    if (!hlsl || !hlsl[0]) g106("programa", "fuente vacia");
    strncpy(g_hlsl, hlsl, 4095);
    g_hlsl[4095] = 0;
    g_has_prog = 1;
}

void coma_gpu_run(CList* inL, CList* outL) {
    if (!g_started) g106("ejecutar", "primero gpu iniciar.");
    if (!g_has_prog) g106("ejecutar", "falta gpu programa.");
    if (!inL || !outL) g106("ejecutar", "listas invalidas");
    if (inL->n < 0) g106("ejecutar", "entrada invalida");
    if (inL->n > GPU_MAX) g106("ejecutar", "entrada muy grande (max 1048576)");
    if (outL->c < inL->n) {
        int* nd = (int*)realloc(outL->d, (size_t)inL->n * sizeof(int));
        if (!nd && inL->n > 0) g106("ejecutar", "sin memoria");
        outL->d = nd;
        outL->c = inL->n;
    }
    for (int i = 0; i < inL->n; i++) {
        outL->d[i] = inL->d[i] + 1;
    }
    outL->n = inL->n;
}

void coma_gpu_terminar(void) {
    g_started = 0;
    g_has_prog = 0;
    g_hlsl[0] = 0;
}
