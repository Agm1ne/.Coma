/* rt_ventana.c — Ventana 2D con píxeles por software puro (sin DirectX/DirectX11).
   Usa solo Win32 GDI para crear ventana y hacer BitBlt del framebuffer. */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
/* Windows: rt_ventana.c provides real implementations; no stubs here. */
#else
/* Sin Windows: sin ventana 2D */
static void g202u(const char* op) {
    printf("E202 ventana %s: no hay ventana 2D en este objetivo", op);
    coma_einfo();
    printf("\n");
    exit(1);
}
void coma_ventana_abrir(int w,int h,const char* t){(void)w;(void)h;(void)t;g202u("abrir");}
void coma_ventana_cerrar(void){}
void coma_ventana_limpiar(void){}
void coma_ventana_color(int r,int g,int b){(void)r;(void)g;(void)b;}
void coma_ventana_rectangulo(int x,int y,int w,int h){(void)x;(void)y;(void)w;(void)h;}
void coma_ventana_circulo(int cx,int cy,int r){(void)cx;(void)cy;(void)r;}
void coma_ventana_linea(int x1,int y1,int x2,int y2){(void)x1;(void)y1;(void)x2;(void)y2;}
void coma_ventana_rotulo(int x,int y,const char* t){(void)x;(void)y;(void)t;}
void coma_ventana_sprite(const char* p,int x,int y){(void)p;(void)x;(void)y;g202u("sprite");}
void coma_ventana_voltear(void){}
int coma_ventana_ancho(void){return 0;}
int coma_ventana_alto(void){return 0;}
int coma_ventana_raton_x(void){return 0;}
int coma_ventana_raton_y(void){return 0;}
int coma_ventana_boton_izq(void){return 0;}
int coma_ventana_boton_der(void){return 0;}
int coma_ventana_tecla(int vk){(void)vk;return 0;}
int coma_ventana_pulsa_tecla(int vk){(void)vk;return 0;}
void coma_finfo(const char* path){ printf("E105 abrir: no se puede (%s). Falta el fichero o permiso denegado (prueba consola de administrador)", path?path:"?"); coma_einfo(); printf("\n"); fflush(stdout); exit(1); }
#endif