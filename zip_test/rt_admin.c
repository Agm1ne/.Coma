/* rt_admin.c — Administrador / servicios con nombre para .Coma
   Contenedor IoC con sesión implícita (current) + instancias con nombre
*/
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void coma_gpu_iniciar(void);
void coma_gpu_programa(const char *src);
void coma_gpu_terminar(void);
void coma_ventana_abrir(int w, int h, const char *title);
void coma_ventana_cerrar(void);
void coma_ventana_limpiar(void);
void coma_ventana_color(int r,int g,int b);
void coma_ventana_rectangulo(int x,int y,int w,int h);
void coma_ventana_circulo(int cx,int cy,int r);
void coma_ventana_linea(int x1,int y1,int x2,int y2);
void coma_ventana_rotulo(int x,int y,const char* txt);
void coma_ventana_sprite(const char* path,int x,int y);
void coma_ventana_voltear(void);
int coma_ventana_ancho(void);
int coma_ventana_alto(void);
int coma_ventana_raton_x(void);
int coma_ventana_raton_y(void);
int coma_ventana_boton_izq(void);
int coma_ventana_boton_der(void);
int coma_ventana_tecla(int vk);
int coma_ventana_pulsa_tecla(int vk);

typedef enum {
    SVC_NONE = 0,
    SVC_FICHERO = 1,
    SVC_SOCKET = 2,
    SVC_WEB = 3,
    SVC_GPU = 4,
    SVC_KERNEL = 5,
    SVC_VENTANA = 6
} svc_kind_t;

typedef struct svc_entry {
    svc_kind_t kind;
    char name[128];
    void *handle;
    int open;
    struct svc_entry *next;
} svc_entry_t;

static svc_entry_t *g_svcs = NULL;
static svc_entry_t *g_current = NULL;

static svc_entry_t *find_svc(const char *name) {
    if (!name) return NULL;
    svc_entry_t *e = g_svcs;
    while (e) {
        if (strcmp(e->name, name) == 0) return e;
        e = e->next;
    }
    return NULL;
}

static svc_entry_t *add_svc(svc_kind_t kind, const char *name, void *h) {
    svc_entry_t *e = (svc_entry_t*)calloc(1, sizeof(svc_entry_t));
    if (!e) return NULL;
    e->kind = kind;
    if (name) strncpy(e->name, name, 127);
    e->handle = h;
    e->open = 1;
    e->next = g_svcs;
    g_svcs = e;
    return e;
}

void coma_admin_servicio_fichero(const char *path, const char *name) {
    svc_entry_t *e = add_svc(SVC_FICHERO, name, (void*)path);
    if (e) g_current = e;
    coma_f_create(path);
}

void coma_admin_servicio_fichero_abrir(const char *path, const char *name) {
    svc_entry_t *e = add_svc(SVC_FICHERO, name, (void*)path);
    if (e) g_current = e;
    coma_f_open(path);
}

void coma_admin_servicio_socket(const char *host, int port, const char *name) {
    svc_entry_t *e = add_svc(SVC_SOCKET, name, NULL);
    if (e) g_current = e;
    coma_net_connect((char*)host, port);
}

void coma_admin_servicio_web(const char *url, const char *name) {
    svc_entry_t *e = add_svc(SVC_WEB, name, (void*)url);
    if (e) g_current = e;
}

void coma_admin_servicio_gpu(const char *name) {
    svc_entry_t *e = add_svc(SVC_GPU, name, NULL);
    if (e) g_current = e;
    coma_gpu_iniciar();
}

void coma_admin_servicio_kernel(const char *src, const char *name) {
    svc_entry_t *e = add_svc(SVC_KERNEL, name, (void*)src);
    if (e) g_current = e;
    coma_gpu_programa((char*)src);
}

void coma_admin_servicio_ventana(int w, int h, const char *title, const char *name) {
    svc_entry_t *e = add_svc(SVC_VENTANA, name, NULL);
    if (e) g_current = e;
    coma_ventana_abrir(w, h, title);
}

void coma_admin_inyectar_fichero(const char *name) {
    svc_entry_t *e = find_svc(name);
    if (!e) { coma_admin_servicio_fichero_abrir(name, name); return; }
    g_current = e;
}

void coma_admin_inyectar_socket(const char *name) {
    svc_entry_t *e = find_svc(name);
    if (e) g_current = e;
}

void coma_admin_inyectar_web(const char *name) {
    svc_entry_t *e = find_svc(name);
    if (e) g_current = e;
}

void coma_admin_inyectar_gpu(const char *name) {
    svc_entry_t *e = find_svc(name);
    if (e) g_current = e;
}

void coma_admin_inyectar_kernel(const char *name) {
    svc_entry_t *e = find_svc(name);
    if (e) g_current = e;
}

void coma_admin_inyectar_ventana(const char *name) {
    svc_entry_t *e = find_svc(name);
    if (e) g_current = e;
}

void coma_admin_cerrar(void) {
    coma_f_close();
    coma_net_close();
    coma_gpu_terminar();
    coma_ventana_cerrar();
    svc_entry_t *e = g_svcs;
    while (e) {
        svc_entry_t *n = e->next;
        free(e);
        e = n;
    }
    g_svcs = NULL;
    g_current = NULL;
}

void coma_admin_mostrar(void) {
    printf("[ADMIN] servicios:\n");
    svc_entry_t *e = g_svcs;
    int i = 0;
    while (e) {
        printf("  %d: %s (%d)\n", i++, e->name, (int)e->kind);
        e = e->next;
    }
    if (i == 0) printf("  (vacio)\n");
}

