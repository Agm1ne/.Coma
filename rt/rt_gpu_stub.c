/* rt_gpu_stub.c — GPU compute stub para Windows (Vulkan no disponible sin headers).
   Las funciones coma_gpu_* son no-ops que imprimen un aviso honesto. */
#include "coma_rt.h"
#include <stdio.h>

void coma_gpu_iniciar(void) {
    printf("gpu: Vulkan no disponible en Windows (usa CPU fallback)\n");
    fflush(stdout);
}
void coma_gpu_programa(const char *hlsl) {
    (void)hlsl;
    printf("gpu: programa ignorado en Windows\n");
    fflush(stdout);
}
void coma_gpu_run(CList *inL, CList *outL) {
    (void)inL; (void)outL;
    printf("gpu: ejecucion ignorada en Windows\n");
    fflush(stdout);
}
void coma_gpu_terminar(void) {
    /* nada */
}
