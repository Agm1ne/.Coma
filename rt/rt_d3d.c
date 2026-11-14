/* rt_d3d.c — Stub de compatibilidad (DirectX eliminado, ahora Vulkan en rt_gpu.c). */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>

void* coma_d3d_device(void) {
    printf("gpu: usando Vulkan (vea rt_gpu.c)\n");
    return NULL;
}

void* coma_d3d_context(void) {
    return NULL;
}

void coma_d3d_release(void) {
}
