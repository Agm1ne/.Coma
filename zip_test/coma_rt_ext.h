/* coma_rt_ext.h — extensiones opcionales del runtime de .Coma.
   Se enlazan SOLO si el programa usa ventana, audio, GPU, BMP, fuentes o HTTPS.
   Cada extensión es independiente.
*/
#ifndef COMA_RT_EXT_H
#define COMA_RT_EXT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* =====================================================================
   Ventana 2D por software (Win32 GDI).
   ===================================================================== */
void coma_ventana_abrir(int w, int h, const char *title);
void coma_ventana_cerrar(void);
void coma_ventana_limpiar(void);
void coma_ventana_color(int r, int g, int b);
void coma_ventana_rectangulo(int x, int y, int w, int h);
void coma_ventana_circulo(int cx, int cy, int r);
void coma_ventana_linea(int x1, int y1, int x2, int y2);
void coma_ventana_rotulo(int x, int y, const char *txt);
void coma_ventana_sprite(const char *path, int x, int y);
void coma_ventana_voltear(void);

/* Carga de BMP para sprites (implementado en rt_bmp.c). */
int coma_bmp_load(const char *path, unsigned char **outData, int *outW, int *outH);

/* =====================================================================
   GPU por single-source CPU (sin DirectX).
   ===================================================================== */
void coma_gpu_iniciar(void);
void coma_gpu_programa(const char *hlsl);
void coma_gpu_run(void *inL, void *outL);
void coma_gpu_terminar(void);

/* =====================================================================
   Audio: exportar listas de enteros (PCM) a WAV / MP3 / OGG según extensión.
   ===================================================================== */
void coma_audio_iniciar(void);
void coma_audio_exportar(void *samples, const char *path);
void coma_audio_terminar(void);

/* =====================================================================
   HTTPS GET mínimo (Schannel en Windows).
   ===================================================================== */
void coma_https_get(const char *url, char **salida);
void coma_https_post(const char *url, const char *body, const char *contentType, char **salida);

#ifdef __cplusplus
}
#endif
#endif /* COMA_RT_EXT_H */
