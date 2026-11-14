#include <stdint.h>
/* rt_thread.c — hilos, tareas y buzones de actores para .Coma
   Windows: CreateThread, Unix: pthread_create
   Detección automática de núcleos + configuración manual hilos máximos
   Buzones de actores: ring buffer de 32 ranuras + 3 backups en RAM (debug).
*/
#include "coma_rt.h"
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

static int g_max_threads = 0;
static int g_num_cores = 0;

/* =====================================================================
   Actor registry y buzones (ring buffer de 32 ranuras + 3 backups)
   ===================================================================== */

#define COMA_MAILBOX_SLOTS 32
#define COMA_MAILBOX_BACKUPS 3

typedef struct {
    int64_t intVal;      /* valor primitivo (si !isHeap) */
    void   *ptrVal;      /* puntero al dato en heap (si isHeap) */
    int     isHeap;      /* 1 = puntero fantasma, 0 = copia por valor */
    int     used;        /* 1 = ranura ocupada */
} coma_mailbox_slot_t;

typedef struct {
    char             name[64];
    int64_t          id;
    coma_mailbox_slot_t slots[COMA_MAILBOX_SLOTS];
    int              head;   /* próxima ranura para escribir */
    int              tail;   /* próxima ranura para leer */
    int              count;  /* ranuras ocupadas */
    /* Backups para debug (últimos 3 estados del buzón) */
    coma_mailbox_slot_t backups[COMA_MAILBOX_BACKUPS][COMA_MAILBOX_SLOTS];
    int              backupIdx;
    int              backupCount;
} coma_actor_t;

static coma_actor_t g_actors[64];
static int g_num_actors = 0;
static int64_t g_next_actor_id = 1;

static coma_actor_t *coma_actor_find_by_name(const char *name) {
    for (int i = 0; i < g_num_actors; i++) {
        if (strcmp(g_actors[i].name, name) == 0) return &g_actors[i];
    }
    return NULL;
}

static coma_actor_t *coma_actor_find_by_id(int64_t id) {
    for (int i = 0; i < g_num_actors; i++) {
        if (g_actors[i].id == id) return &g_actors[i];
    }
    return NULL;
}

static void coma_mailbox_backup(coma_actor_t *a) {
    /* Guardar snapshot del buzón actual en el backup correspondiente */
    int bi = a->backupIdx % COMA_MAILBOX_BACKUPS;
    for (int i = 0; i < COMA_MAILBOX_SLOTS; i++) {
        a->backups[bi][i] = a->slots[i];
    }
    a->backupIdx++;
    if (a->backupCount < COMA_MAILBOX_BACKUPS) a->backupCount++;
}

int64_t coma_actor_create(const char *name, int64_t *outId) {
    if (g_num_actors >= 64) return -1;
    if (coma_actor_find_by_name(name)) return -1; /* ya existe */
    coma_actor_t *a = &g_actors[g_num_actors++];
    memset(a, 0, sizeof(*a));
    strncpy(a->name, name, 63);
    a->name[63] = '\0';
    a->id = g_next_actor_id++;
    a->head = 0;
    a->tail = 0;
    a->count = 0;
    a->backupIdx = 0;
    a->backupCount = 0;
    if (outId) *outId = a->id;
    return a->id;
}

/* Enviar mensaje al buzón del actor. Bloquea si está lleno. */
void coma_mailbox_send(int64_t actorId, const char *namePtr, int isHeap,
                       int64_t intVal, void *ptrVal) {
    coma_actor_t *a = NULL;
    if (actorId != 0) {
        a = coma_actor_find_by_id(actorId);
    } else if (namePtr) {
        a = coma_actor_find_by_name(namePtr);
    }
    if (!a) return; /* actor no existe: descartar silenciosamente */

    /* Esperar hasta que haya espacio (backpressure) */
    while (a->count >= COMA_MAILBOX_SLOTS) {
#ifdef _WIN32
        Sleep(1);
#else
        usleep(1000);
#endif
    }

    /* Hacer backup del estado actual antes de modificar */
    coma_mailbox_backup(a);

    /* Escribir en la ranura head */
    int slot = a->head % COMA_MAILBOX_SLOTS;
    a->slots[slot].intVal = intVal;
    a->slots[slot].ptrVal = ptrVal;
    a->slots[slot].isHeap = isHeap;
    a->slots[slot].used = 1;
    a->head = (a->head + 1) % COMA_MAILBOX_SLOTS;
    a->count++;
}

/* Recibir mensaje del buzón del actor actual.
   Devuelve 1 si hay mensaje, 0 si vacío, -1 si error. */
int coma_mailbox_recv(const char *namePtr, int64_t *intValOut, void **ptrValOut) {
    coma_actor_t *a = NULL;
    if (namePtr) {
        a = coma_actor_find_by_name(namePtr);
    }
    if (!a) return -1;

    if (a->count == 0) return 0; /* buzón vacío */

    int slot = a->tail % COMA_MAILBOX_SLOTS;
    if (!a->slots[slot].used) return 0;

    if (intValOut) *intValOut = a->slots[slot].intVal;
    if (ptrValOut) *ptrValOut = a->slots[slot].ptrVal;
    a->slots[slot].used = 0;
    a->tail = (a->tail + 1) % COMA_MAILBOX_SLOTS;
    a->count--;
    return 1;
}

int coma_hilos_init(void) {
#ifdef _WIN32
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    g_num_cores = (int)si.dwNumberOfProcessors;
#else
    g_num_cores = (int)sysconf(_SC_NPROCESSORS_ONLN);
#endif
    if (g_num_cores <= 0) g_num_cores = 4;
    if (g_max_threads <= 0) g_max_threads = g_num_cores;
    if (g_max_threads < 1) g_max_threads = 1;
    return g_num_cores;
}

void coma_hilos_maximos(int n) {
    if (n < 1) n = 1;
    if (g_num_cores > 0 && n > g_num_cores * 2) n = g_num_cores * 2;
    g_max_threads = n;
}

int coma_hilos_obtener_maximos(void) {
    if (g_max_threads <= 0) coma_hilos_init();
    return g_max_threads;
}

int coma_hilos_obtener_nucleos(void) {
    if (g_num_cores <= 0) coma_hilos_init();
    return g_num_cores;
}

typedef struct {
    void (*func)(void*);
    void *arg;
} coma_thread_task_t;

#ifdef _WIN32
static DWORD WINAPI coma_thread_trampoline(LPVOID lp) {
    coma_thread_task_t *t = (coma_thread_task_t*)lp;
    if (t && t->func) t->func(t->arg);
    free(t);
    return 0;
}
#else
static void *coma_thread_trampoline(void *p) {
    coma_thread_task_t *t = (coma_thread_task_t*)p;
    if (t && t->func) t->func(t->arg);
    free(t);
    return NULL;
}
#endif

void coma_tarea_lanzar(void (*func)(void*), void *arg) {
    if (g_num_cores <= 0) coma_hilos_init();
    coma_thread_task_t *t = (coma_thread_task_t*)malloc(sizeof(coma_thread_task_t));
    if (!t) return;
    t->func = func;
    t->arg = arg;
#ifdef _WIN32
    HANDLE h = CreateThread(NULL, 0, coma_thread_trampoline, t, 0, NULL);
    if (h) CloseHandle(h);
    else free(t);
#else
    pthread_t tid;
    if (pthread_create(&tid, NULL, coma_thread_trampoline, t) != 0) {
        free(t);
    } else {
        pthread_detach(tid);
    }
#endif
}

/* =====================================================================
   Manejo de errores: try/catch/lanzar
   Usa setjmp/longjmp para saltar al catch más cercano.
   ===================================================================== */

#define COMA_MAX_TRY_DEPTH 32

static jmp_buf g_try_stack[COMA_MAX_TRY_DEPTH];
static int g_try_depth = 0;
static char g_error_msg[1024] = "";

/* Lanza un error. Si hay un try activo, salta al catch. Si no, imprime y sale. */
void coma_throw(const char *msg) {
    strncpy(g_error_msg, msg, 1023);
    g_error_msg[1023] = '\0';
    if (g_try_depth > 0) {
        longjmp(g_try_stack[g_try_depth - 1], 1);
    }
    fprintf(stderr, "Error no controlado: %s\n", msg);
    exit(1);
}

/* Devuelve el mensaje del último error lanzado. */
const char *coma_get_thrown_error(void) {
    return g_error_msg;
}

/* Marca el inicio de un bloque try. Guarda el buffer de setjmp. */
void coma_try_begin(jmp_buf buf) {
    if (g_try_depth < COMA_MAX_TRY_DEPTH) {
        memcpy(&g_try_stack[g_try_depth], &buf, sizeof(jmp_buf));
        g_try_depth++;
    }
}

/* Marca el final de un bloque try. */
void coma_try_end(void) {
    if (g_try_depth > 0) {
        g_try_depth--;
    }
}

/* Inicializa el contexto de error para un hilo. */
void coma_error_init(void) {
    g_try_depth = 0;
    g_error_msg[0] = '\0';
}

/* =====================================================================
   Canales thread-safe (canal crear / enviar / recibir)
   ===================================================================== */

#define COMA_MAX_CHANNELS 64
#define COMA_CHANNEL_BUFFER 32

typedef struct {
    char name[64];
    int64_t buffer[COMA_CHANNEL_BUFFER];
    int head, tail, count;
    int closed;
#ifdef _WIN32
    HANDLE mutex;
    HANDLE canSend;
    HANDLE canRecv;
#else
    pthread_mutex_t mutex;
    pthread_cond_t canSend;
    pthread_cond_t canRecv;
#endif
} coma_channel_t;

static coma_channel_t g_channels[COMA_MAX_CHANNELS];
static int g_num_channels = 0;

static coma_channel_t *coma_channel_find(const char *name) {
    for (int i = 0; i < g_num_channels; i++) {
        if (strcmp(g_channels[i].name, name) == 0) return &g_channels[i];
    }
    return NULL;
}

void coma_channel_create(const char *name) {
    if (g_num_channels >= COMA_MAX_CHANNELS) return;
    if (coma_channel_find(name)) return;
    coma_channel_t *c = &g_channels[g_num_channels++];
    memset(c, 0, sizeof(*c));
    strncpy(c->name, name, 63);
    c->name[63] = '\0';
    c->head = 0;
    c->tail = 0;
    c->count = 0;
    c->closed = 0;
#ifdef _WIN32
    c->mutex = CreateMutex(NULL, FALSE, NULL);
    c->canSend = CreateSemaphore(NULL, COMA_CHANNEL_BUFFER, COMA_CHANNEL_BUFFER, NULL);
    c->canRecv = CreateSemaphore(NULL, 0, COMA_CHANNEL_BUFFER, NULL);
#else
    pthread_mutex_init(&c->mutex, NULL);
    pthread_cond_init(&c->canSend, NULL);
    pthread_cond_init(&c->canRecv, NULL);
#endif
}

void coma_channel_send(const char *name, int64_t val) {
    coma_channel_t *c = coma_channel_find(name);
    if (!c) return;
#ifdef _WIN32
    WaitForSingleObject(c->canSend, INFINITE);
    WaitForSingleObject(c->mutex, INFINITE);
#else
    pthread_mutex_lock(&c->mutex);
    while (c->count >= COMA_CHANNEL_BUFFER) pthread_cond_wait(&c->canSend, &c->mutex);
#endif
    c->buffer[c->head] = val;
    c->head = (c->head + 1) % COMA_CHANNEL_BUFFER;
    c->count++;
#ifdef _WIN32
    ReleaseMutex(c->mutex);
    ReleaseSemaphore(c->canRecv, 1, NULL);
#else
    pthread_cond_signal(&c->canRecv);
    pthread_mutex_unlock(&c->mutex);
#endif
}

int coma_channel_recv(const char *name, int64_t *out) {
    coma_channel_t *c = coma_channel_find(name);
    if (!c) return -1;
#ifdef _WIN32
    WaitForSingleObject(c->canRecv, INFINITE);
    WaitForSingleObject(c->mutex, INFINITE);
#else
    pthread_mutex_lock(&c->mutex);
    while (c->count == 0) pthread_cond_wait(&c->canRecv, &c->mutex);
#endif
    *out = c->buffer[c->tail];
    c->tail = (c->tail + 1) % COMA_CHANNEL_BUFFER;
    c->count--;
#ifdef _WIN32
    ReleaseMutex(c->mutex);
    ReleaseSemaphore(c->canSend, 1, NULL);
#else
    pthread_cond_signal(&c->canSend);
    pthread_mutex_unlock(&c->mutex);
#endif
    return 1;
}
