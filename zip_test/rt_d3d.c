/* rt_d3d.c — Sin DirectX: CPU puro (compatibilidad de interfaz) */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>

void* coma_d3d_device(void) {
    printf("gpu: CPU (sin DirectX)\n");
    return NULL;
}

void* coma_d3d_context(void) {
    return NULL;
}

void coma_d3d_release(void) {
}
