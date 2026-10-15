/* coma_rt.h — runtime portable de .Coma (teclado, consola, tiempo, mandos).
   La IR generada SOLO llama a coma_*. El driver elige rt_win.c o rt_unix.c
   segun el --target. Sin dependencias salvo libc (+ winmm/XInput por
   carga dinamica en Windows: cero flags de enlace). */
#ifndef COMA_RT_H
#define COMA_RT_H

#ifdef __cplusplus
extern "C" {
#endif

/* Consola: UTF-8 + ANSI/VT si se puede; si falla (tubo) no hace nada. */
void coma_console_init(void);

/* Teclado no bloqueante. Contrato: llamar a coma_getch solo si coma_kbhit.
   coma_getch devuelve minuscula; flechas mapeadas a w/s/a/d. */
int coma_kbhit(void);
int coma_getch(void);

/* Estado asincrono de tecla (letras/flechas estilo Tecla "a"/"izquierda").
   Códigos: ASCII en mayúsculas para letras, 37/38/39/40 izq/arr/der/aba. */
int coma_key_down(int vk);

/* Pausa en milisegundos. */
void coma_sleep_ms(int ms);

/* Leer una línea de consola (heap, sin tope). *dst siempre válido. */
void coma_pedir(char **dst);

/* --- Fase sin-límites: heap propio, cero dependencias --- */
/* Texto dinámico: *dst siempre válido tras asignar (NULL src = ""). */
void coma_str_assign(char **dst, const char *src);
void coma_str_free(char *p);

/* Lista dinámica de enteros (sin tope 64). Índices 0-based; fuera = E101. */
typedef struct { int *d; int n, c; } CList;
int coma_list_len(CList *h);
int coma_list_get(CList *h, int i);
void coma_list_set(CList *h, int i, int v);
void coma_list_add(CList *h, int v);
void coma_list_rmval(CList *h, int v);
void coma_list_rmat(CList *h, int i);
void coma_list_reset(CList *h);
void coma_list_copy(CList *dst, CList *src);
void coma_list_free(CList *h);

/* Lista dinámica de textos (sin tope; copia profunda: cada elemento es heap propio). */
typedef struct { char **d; int n, c; } CListStr;
int coma_slist_len(CListStr *h);
const char *coma_slist_get(CListStr *h, int i);
void coma_slist_set(CListStr *h, int i, const char *v);
void coma_slist_add(CListStr *h, const char *v);
void coma_slist_rmval(CListStr *h, const char *v);
void coma_slist_rmat(CListStr *h, int i);
void coma_slist_reset(CListStr *h);
void coma_slist_copy(CListStr *dst, CListStr *src);
void coma_slist_free(CListStr *h);

/* Lista de listas de enteros (sin tope; copia profunda en cada nivel). */
typedef struct { CList *d; int n, c; } CListList;
int coma_llist_len(CListList *h);
void coma_llist_get(CListList *h, int i, CList *out);
void coma_llist_set(CListList *h, int i, CList *v);
void coma_llist_add(CListList *h, CList *v);
void coma_llist_rmval(CListList *h, CList *v);
void coma_llist_rmat(CListList *h, int i);
void coma_llist_reset(CListList *h);
void coma_llist_copy(CListList *dst, CListList *src);
void coma_llist_free(CListList *h);

/* Lista de registros de enteros (filas de ancho fijo; E101 fuera de rango). */
typedef struct { int *d; int nrows, ncols; } CRecList;
void coma_rlist_reset(CRecList *h, int ncols);
void coma_rlist_addrow(CRecList *h);
int coma_rlist_len(CRecList *h);
int coma_rlist_get(CRecList *h, int r, int c);
void coma_rlist_set(CRecList *h, int r, int c, int v);
void coma_rlist_copy(CRecList *dst, CRecList *src);
void coma_rlist_free(CRecList *h);

/* pedir numérico con reintento E103 (EOF/vacío = 0 y sigue). */
int coma_pedir_int(int *out);
int coma_pedir_dbl(double *out);

/* Comparación de texto insensible a mayúsculas/minúsculas */
int coma_stricmp(const char *a, const char *b);

/* Espera de tick por rebanadas de 1 ms muestreando teclado (FIFO 16). */
void coma_tick_wait(int ms);

/* Mandos + guitarras (GH) + palancas. pad 0..3. Todo 0/"" sin hardware. */
int coma_pad_count(void);
int coma_pad_down(int pad, int code);
const char *coma_pad_last(int pad);

/* Ficheros (sesión única) y presets del sistema. Errores = E105 + exit. */
void coma_f_open(const char *path);
void coma_f_create(const char *path);
void coma_f_read(char **dst);
void coma_f_write_str(const char *s);
void coma_f_write_int(int v);
void coma_f_write_dbl(double v);
void coma_f_close(void);
void coma_f_delete(const char *path);

/* Red (sesión única TCP): conectar cierra la anterior sola. Errores = E106 + exit. */
void coma_net_connect(const char *host, int port);
void coma_net_send_str(const char *s);
void coma_net_send_int(int v);
void coma_net_send_dbl(double v);
void coma_net_recv(char **dst);
void coma_net_close(void);

/* Presets: 1 hora, 2 fecha, 3 usuario, 4 sistema, 5 version, 6 carpeta. */
enum { SYS_HORA = 1, SYS_FECHA = 2, SYS_USUARIO = 3,
       SYS_SISTEMA = 4, SYS_VERSION = 5, SYS_CARPETA = 6 };
const char *coma_sys_info(int which);

/* Códigos de coma_pad_down (valen ES/EN en el lenguaje): */
enum {
  COMA_PAD_A = 1, COMA_PAD_B = 2, COMA_PAD_X = 3, COMA_PAD_Y = 4,
  COMA_PAD_LB = 5, COMA_PAD_RB = 6, COMA_PAD_BACK = 7, COMA_PAD_START = 8,
  COMA_PAD_LSTICK = 9, COMA_PAD_RSTICK = 10,
  COMA_PAD_UP = 11, COMA_PAD_DOWN = 12, COMA_PAD_LEFT = 13, COMA_PAD_RIGHT = 14,
  /* Trastes de Guitar Hero (verde, roja, amarilla, azul, naranja): */
  COMA_FRET_GREEN = 20, COMA_FRET_RED = 21, COMA_FRET_YELLOW = 22,
  COMA_FRET_BLUE = 23, COMA_FRET_ORANGE = 24,
  /* Púa (rasgueo) arriba/abajo, palanca (whammy), inclinación (star power): */
  COMA_STRUM_UP = 25, COMA_STRUM_DOWN = 26,
  COMA_WHAMMY = 27, COMA_TILT = 28
};

/* Mapeo Guitar Hero documentado (best-effort, los adaptadores varían):
   - XInput (360 Xplorer y clones): trastes = A/B/Y/X/LB (verde,roja,
     amarilla,azul,naranja); púa = cruceta arr/aba; whammy = stick
     derecho Y; start/select directos. Tilt sin acelerómetro = 0.
   - winmm/DirectInput (adaptadores PS2/RT): botones 0-4 = trastes;
     POV arr/aba = púa; botón 9 = start, 8 = select; eje Z = whammy.
   - Linux evdev: BTN_0-4 (o A/B/X/Y/LB) = trastes; BTN_5/6 = púa
     aba/arr; ABS_Z/RZ desviado = whammy. Requiere grupo `input`. */

#ifdef __cplusplus
}
#endif
#endif
