/* rt_ventana.c — Ventana 2D con OpenGL 3.3.
   Renderiza en un framebuffer de software (CPU) y lo sube a una textura
   cada frame. */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define COBJMACROS
#include <windows.h>
#include <windowsx.h>
#include <GL/gl.h>

/* Forward declaration for BMP loader */
int coma_bmp_load(const char *path, unsigned char **outData, int *outW, int *outH);

/* GL 1.3 function (may not be in legacy gl.h/lib) */
typedef void (APIENTRY *PFN_ACTIVETEXTURE)(GLenum texture);
static PFN_ACTIVETEXTURE pglActiveTexture = NULL;

/* Ensure APIENTRYP and extensions are available */
#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif
typedef int GLsizeiptr;
typedef char GLchar;
typedef unsigned int GLDEBUGPROC;

/* --- WGL constants --- */
#ifndef WGL_CONTEXT_MAJOR_VERSION_ARB
#define WGL_CONTEXT_MAJOR_VERSION_ARB 0x2041
#define WGL_CONTEXT_MINOR_VERSION_ARB 0x2042
#define WGL_CONTEXT_PROFILE_MASK_ARB 0x9126
#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB 0x0001
#define WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB 0x0002
#define WGL_CONTEXT_FLAGS_ARB 0x3030
#define WGL_CONTEXT_FORWARD_COMPATIBLE_FLAG_ARB 0x0002
#endif

/* --- GL 3.3 constants --- */
#ifndef GL_ARRAY_BUFFER
#define GL_ARRAY_BUFFER 0x8892
#endif
#ifndef GL_ELEMENT_ARRAY_BUFFER
#define GL_ELEMENT_ARRAY_BUFFER 0x8893
#endif
#ifndef GL_STATIC_DRAW
#define GL_STATIC_DRAW 0x88E4
#endif
#ifndef GL_TEXTURE_MIN_FILTER
#define GL_TEXTURE_MIN_FILTER 0x2801
#endif
#ifndef GL_TEXTURE_MAG_FILTER
#define GL_TEXTURE_MAG_FILTER 0x2800
#endif
#ifndef GL_TEXTURE_WRAP_S
#define GL_TEXTURE_WRAP_S 0x2802
#endif
#ifndef GL_TEXTURE_WRAP_T
#define GL_TEXTURE_WRAP_T 0x2803
#endif
#ifndef GL_CLAMP_TO_EDGE
#define GL_CLAMP_TO_EDGE 0x812F
#endif
#ifndef GL_NEAREST
#define GL_NEAREST 0x2600
#endif
#ifndef GL_UNSIGNED_SHORT
#define GL_UNSIGNED_SHORT 0x1403
#endif
#ifndef GL_TEXTURE0
#define GL_TEXTURE0 0x84C0
/* pglActiveTexture loaded dynamically */
#endif
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_BGRA 0x80E1

/* GL function pointer typedefs */
typedef void (APIENTRYP PFN_GENVERTEXARRAYS)(GLsizei n, GLuint *arrays);
typedef void (APIENTRYP PFN_BINDVERTEXARRAY)(GLuint array);
typedef void (APIENTRYP PFN_GENBUFFERS)(GLsizei n, GLuint *buffers);
typedef void (APIENTRYP PFN_BINDBUFFER)(GLenum target, GLuint buffer);
typedef void (APIENTRYP PFN_BUFFERDATA)(GLenum target, GLsizeiptr size, const void *data, GLenum usage);
typedef void (APIENTRYP PFN_ENABLEVERTEXATTRIB)(GLuint index);
typedef void (APIENTRYP PFN_VERTEXATTRIBPOINTER)(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
typedef void (APIENTRYP PFN_GENSAMPLERS)(GLsizei n, GLuint *samplers);
typedef void (APIENTRYP PFN_SAMPLERPARAMETERI)(GLuint sampler, GLenum pname, GLint param);
typedef GLuint (APIENTRYP PFN_CREATESHADER)(GLenum type);
typedef void (APIENTRYP PFN_SHADERSOURCE)(GLuint shader, GLsizei count, const GLchar **string, const GLint *length);
typedef void (APIENTRYP PFN_COMPILESHADER)(GLuint shader);
typedef void (APIENTRYP PFN_GETSHADERIV)(GLuint shader, GLenum pname, GLint *params);
typedef void (APIENTRYP PFN_GETSHADERINFOLOG)(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
typedef GLuint (APIENTRYP PFN_CREATEPROGRAM)(void);
typedef void (APIENTRYP PFN_ATTACHSHADER)(GLuint program, GLuint shader);
typedef void (APIENTRYP PFN_LINKPROGRAM)(GLuint program);
typedef void (APIENTRYP PFN_GETPROGRAMIV)(GLuint program, GLenum pname, GLint *params);
typedef void (APIENTRYP PFN_GETPROGRAMINFOLOG)(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
typedef void (APIENTRYP PFN_USEPROGRAM)(GLuint program);
typedef GLint (APIENTRYP PFN_GETUNIFORMLOCATION)(GLuint program, const GLchar *name);
typedef void (APIENTRYP PFN_UNIFORM1I)(GLint location, GLint v0);

typedef HGLRC (APIENTRYP PFN_WGL_CREATECONTEXTATTRIBS)(HDC hdc, HGLRC hshare, const int *attribList);
typedef const char* (APIENTRYP PFN_WGL_GETEXTENSIONSSTRING)(HDC hdc);

/* GL function pointers */
static PFN_GENVERTEXARRAYS pglGenVertexArrays = NULL;
static PFN_BINDVERTEXARRAY pglBindVertexArray = NULL;
static PFN_GENBUFFERS pglGenBuffers = NULL;
static PFN_BINDBUFFER pglBindBuffer = NULL;
static PFN_BUFFERDATA pglBufferData = NULL;
static PFN_ENABLEVERTEXATTRIB pglEnableVertexAttribArray = NULL;
static PFN_VERTEXATTRIBPOINTER pglVertexAttribPointer = NULL;
static PFN_GENSAMPLERS pglGenSamplers = NULL;
static PFN_SAMPLERPARAMETERI pglSamplerParameteri = NULL;
static PFN_CREATESHADER pglCreateShader = NULL;
static PFN_SHADERSOURCE pglShaderSource = NULL;
static PFN_COMPILESHADER pglCompileShader = NULL;
static PFN_GETSHADERIV pglGetShaderiv = NULL;
static PFN_GETSHADERINFOLOG pglGetShaderInfoLog = NULL;
static PFN_CREATEPROGRAM pglCreateProgram = NULL;
static PFN_ATTACHSHADER pglAttachShader = NULL;
static PFN_LINKPROGRAM pglLinkProgram = NULL;
static PFN_GETPROGRAMIV pglGetProgramiv = NULL;
static PFN_GETPROGRAMINFOLOG pglGetProgramInfoLog = NULL;
static PFN_USEPROGRAM pglUseProgram = NULL;
static PFN_GETUNIFORMLOCATION pglGetUniformLocation = NULL;
static PFN_UNIFORM1I pglUniform1i = NULL;

static PFN_WGL_CREATECONTEXTATTRIBS pwglCreateContextAttribs = NULL;

static HWND g_hwnd = NULL;
static HDC g_hdc = NULL;
static HGLRC g_glrc = NULL;
static int g_w = 0, g_h = 0;
static int g_open = 0;
static unsigned char g_r = 255, g_g = 255, g_b = 255;
static unsigned char *g_fb = NULL;
static GLuint g_tex = 0, g_vao = 0, g_vbo = 0, g_ebo = 0;
static GLuint g_prog = 0, g_samp = 0;
static unsigned char g_key[256];
static unsigned char g_key_prev[256];
static int g_mx = 0, g_my = 0, g_mb = 0;

static void g202(const char *op) {
    fflush(stdout);
    printf("E202 ventana %s", op);
    coma_einfo();
    printf("\n");
    exit(1);
}

static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
static int wgl_init(HDC hdc);
static void gl_load_procs(void);

static void gl_load_procs(void) {
#define LOAD(name, type) name = (type)wglGetProcAddress("gl" #name); \
    if (!name) name = (type)wglGetProcAddress("gl" #name "ARB");

    LOAD(pglGenVertexArrays, PFN_GENVERTEXARRAYS)
    LOAD(pglBindVertexArray, PFN_BINDVERTEXARRAY)
    LOAD(pglGenBuffers, PFN_GENBUFFERS)
    LOAD(pglBindBuffer, PFN_BINDBUFFER)
    LOAD(pglBufferData, PFN_BUFFERDATA)
    LOAD(pglEnableVertexAttribArray, PFN_ENABLEVERTEXATTRIB)
    LOAD(pglVertexAttribPointer, PFN_VERTEXATTRIBPOINTER)
    LOAD(pglGenSamplers, PFN_GENSAMPLERS)
    LOAD(pglSamplerParameteri, PFN_SAMPLERPARAMETERI)
    LOAD(pglCreateShader, PFN_CREATESHADER)
    LOAD(pglShaderSource, PFN_SHADERSOURCE)
    LOAD(pglCompileShader, PFN_COMPILESHADER)
    LOAD(pglGetShaderiv, PFN_GETSHADERIV)
    LOAD(pglGetShaderInfoLog, PFN_GETSHADERINFOLOG)
    LOAD(pglCreateProgram, PFN_CREATEPROGRAM)
    LOAD(pglAttachShader, PFN_ATTACHSHADER)
    LOAD(pglLinkProgram, PFN_LINKPROGRAM)
    LOAD(pglGetProgramiv, PFN_GETPROGRAMIV)
    LOAD(pglGetProgramInfoLog, PFN_GETPROGRAMINFOLOG)
    LOAD(pglUseProgram, PFN_USEPROGRAM)
    LOAD(pglGetUniformLocation, PFN_GETUNIFORMLOCATION)
    LOAD(pglUniform1i, PFN_UNIFORM1I)
    /* pglActiveTexture loads "glActiveTexture" */
#undef LOAD
    pglActiveTexture = (PFN_ACTIVETEXTURE)wglGetProcAddress("glActiveTexture");
    if (!pglActiveTexture) pglActiveTexture = (PFN_ACTIVETEXTURE)wglGetProcAddress("glActiveTextureARB");
}

static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CLOSE: g_open = 0; return 0;
    case WM_KEYDOWN: if (wParam < 256) g_key[wParam] = 1; return 0;
    case WM_KEYUP: if (wParam < 256) g_key[wParam] = 0; return 0;
    case WM_MOUSEMOVE: g_mx = GET_X_LPARAM(lParam); g_my = GET_Y_LPARAM(lParam); return 0;
    case WM_LBUTTONDOWN: g_mb |= 1; return 0;
    case WM_LBUTTONUP: g_mb &= ~1; return 0;
    case WM_RBUTTONDOWN: g_mb |= 2; return 0;
    case WM_RBUTTONUP: g_mb &= ~2; return 0;
    case WM_SIZE:
        if (g_open && wParam != SIZE_MINIMIZED) {
            int nw = LOWORD(lParam), nh = HIWORD(lParam);
            if (nw > 0 && nh > 0) {
                g_w = nw; g_h = nh;
                if (g_fb) {
                    free(g_fb);
                    g_fb = (unsigned char *)malloc((size_t)g_w * g_h * 4);
                }
                if (g_fb) {
                    memset(g_fb, 0, (size_t)g_w * g_h * 4);
                }
            }
        }
        return 0;
    case WM_DESTROY: PostQuitMessage(0); return 0;
    default: return DefWindowProc(hWnd, msg, wParam, lParam);
    }
}


typedef BOOL (WINAPI *PFNWGLCHOOSEPIXELFORMATARBPROC)(HDC hdc, const int *piAttribIList, const FLOAT *pfAttribFList, UINT nMaxFormats, int *piFormats, UINT *nNumFormats);

static int wgl_init(HDC hdc) {
    PIXELFORMATDESCRIPTOR pfd = {
        sizeof(PIXELFORMATDESCRIPTOR), 1,
        PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        PFD_TYPE_RGBA, 32, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 24, 8, 0,
        PFD_MAIN_PLANE, 0, 0, 0, 0
    };
    int pf = ChoosePixelFormat(hdc, &pfd);
    if (!pf) { printf("wgl_init: ChoosePixelFormat failed\n"); return 0; }
    if (!SetPixelFormat(hdc, pf, &pfd)) { printf("wgl_init: SetPixelFormat failed\n"); return 0; }

    HGLRC rc = wglCreateContext(hdc);
    if (!rc) { printf("wgl_init: wglCreateContext failed\n"); return 0; }
    if (!wglMakeCurrent(hdc, rc)) { printf("wgl_init: wglMakeCurrent failed\n"); return 0; }

    g_glrc = rc;
    gl_load_procs();

    const GLubyte *ver = glGetString(GL_VERSION);
    printf("OpenGL version: %s\n", ver ? (const char *)ver : "unknown");

    /* Accept any GL version - use fallback if 3.3 not available */
    if (!pglGenVertexArrays) {
        printf("wgl_init: VAO not available, will use fallback rendering\n");
    }
    printf("wgl_init: OK\n");
    return 1;
}

void coma_ventana_abrir(int w, int h, const char *title) {
    if (g_open) return;
    if (w <= 0 || h <= 0) { w = 800; h = 600; }
    if (!title) title = ".Coma";

    HINSTANCE hInst = GetModuleHandle(NULL);
    WNDCLASSA wc;
    memset(&wc, 0, sizeof(wc));
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInst;
    wc.lpszClassName = "ComaGL";
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassA(&wc);

    RECT rc = {0, 0, w, h};
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
    g_hwnd = CreateWindowExA(0, "ComaGL", title, WS_OVERLAPPEDWINDOW,
                             CW_USEDEFAULT, CW_USEDEFAULT,
                             rc.right - rc.left, rc.bottom - rc.top,
                             NULL, NULL, hInst, NULL);
    if (!g_hwnd) g202("abrir");

    ShowWindow(g_hwnd, SW_SHOW);
    UpdateWindow(g_hwnd);
    SetForegroundWindow(g_hwnd);
    SetFocus(g_hwnd);

    g_hdc = GetDC(g_hwnd);
    if (!g_hdc) g202("abrir");

    if (!wgl_init(g_hdc)) g202("abrir");

    g_w = w; g_h = h;
    g_open = 1;

    /* Framebuffer de software */
    g_fb = (unsigned char *)malloc((size_t)g_w * g_h * 4);
    if (!g_fb) { printf("E202 ventana framebuffer\n"); exit(1); }
    memset(g_fb, 0, (size_t)g_w * g_h * 4);

    /* OpenGL setup skipped - using GDI for rendering */
}

void coma_ventana_limpiar(void) {
    if (!g_open || !g_fb) return;
    memset(g_fb, 0, (size_t)g_w * g_h * 4);
}

void coma_ventana_color(int r, int g, int b) {
    if (r < 0) r = 0; if (r > 255) r = 255;
    if (g < 0) g = 0; if (g > 255) g = 255;
    if (b < 0) b = 0; if (b > 255) b = 255;
    g_r = (unsigned char)r; g_g = (unsigned char)g; g_b = (unsigned char)b;
}

static void fb_set_pixel(int x, int y, unsigned char r, unsigned char g, unsigned char b) {
    if (!g_fb || x < 0 || y < 0 || x >= g_w || y >= g_h) return;
    int idx = (y * g_w + x) * 4;
    g_fb[idx] = b;     /* BGRA */
    g_fb[idx+1] = g;
    g_fb[idx+2] = r;
    g_fb[idx+3] = 255;
}

static void px(int x, int y) {
    fb_set_pixel(x, y, g_r, g_g, g_b);
}

void coma_ventana_rectangulo(int x, int y, int w, int h) {
    if (!g_open) return;
    for (int yy = y; yy < y + h; yy++)
        for (int xx = x; xx < x + w; xx++)
            px(xx, yy);
}

void coma_ventana_circulo(int cx, int cy, int r) {
    if (!g_open || r <= 0) return;
    for (int y = -r; y <= r; y++)
        for (int x = -r; x <= r; x++)
            if (x * x + y * y <= r * r)
                px(cx + x, cy + y);
}

void coma_ventana_linea(int x1, int y1, int x2, int y2) {
    if (!g_open) return;
    int dx = abs(x2 - x1), dy = abs(y2 - y1);
    int sx = x1 < x2 ? 1 : -1, sy = y1 < y2 ? 1 : -1;
    int err = dx - dy;
    while (1) {
        px(x1, y1);
        if (x1 == x2 && y1 == y2) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x1 += sx; }
        if (e2 < dx) { err += dx; y1 += sy; }
    }
}

const unsigned char *coma_font8x8_get(int c);

void coma_ventana_rotulo(int x, int y, const char *txt) {
    if (!g_open || !txt) return;
    int cx = x;
    for (const char *p = txt; *p; p++) {
        unsigned char c = (unsigned char)*p;
        const unsigned char *g = coma_font8x8_get(c);
        for (int yy = 0; yy < 8; yy++) {
            unsigned char row = g[yy];
            for (int xx = 0; xx < 8; xx++)
                if (row & (1 << (7 - xx)))
                    px(cx + xx, y + yy);
        }
        cx += 8;
    }
}

void coma_ventana_sprite(const char *path, int x, int y) {
    if (!g_open || !path) g202("sprite");
    unsigned char *data = NULL;
    int w = 0, h = 0;
    if (!coma_bmp_load(path, &data, &w, &h)) g202("sprite");
    for (int yy = 0; yy < h; yy++)
        for (int xx = 0; xx < w; xx++) {
            int i = (yy * w + xx) * 4;
            unsigned char r = data[i + 0], gr = data[i + 1], b = data[i + 2], a = data[i + 3];
            if (a == 0) continue;
            int px2 = x + xx, py2 = y + yy;
            if (px2 < 0 || px2 >= g_w || py2 < 0 || py2 >= g_h) continue;
            g_fb[(py2 * g_w + px2) * 4 + 0] = b;
            g_fb[(py2 * g_w + px2) * 4 + 1] = gr;
            g_fb[(py2 * g_w + px2) * 4 + 2] = r;
            g_fb[(py2 * g_w + px2) * 4 + 3] = 255;
        }
    free(data);
}

void coma_ventana_voltear(void) {
    if (!g_open) return;

    /* Use GDI StretchDIBits instead of OpenGL */
    BITMAPINFO bmi;
    memset(&bmi, 0, sizeof(bmi));
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = g_w;
    bmi.bmiHeader.biHeight = -g_h; /* top-down */
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    StretchDIBits(g_hdc, 0, 0, g_w, g_h, 0, 0, g_w, g_h,
                  g_fb, &bmi, DIB_RGB_COLORS, SRCCOPY);

    MSG msg;
    while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    for (int i = 0; i < 256; i++) g_key_prev[i] = g_key[i];
}

int coma_ventana_ancho(void) { return g_w; }
int coma_ventana_alto(void) { return g_h; }
int coma_ventana_raton_x(void) { return g_mx; }
int coma_ventana_raton_y(void) { return g_my; }
int coma_ventana_boton_izq(void) { return (g_mb & 1) ? 1 : 0; }
int coma_ventana_boton_der(void) { return (g_mb & 2) ? 1 : 0; }

int coma_ventana_tecla(int vk) {
    if (vk < 0 || vk >= 256) return 0;
    if (vk >= 'a' && vk <= 'z') vk = vk - 'a' + 'A';
    return g_key[vk] ? 1 : 0;
}

int coma_ventana_pulsa_tecla(int vk) {
    if (vk < 0 || vk >= 256) return 0;
    if (vk >= 'a' && vk <= 'z') vk = vk - 'a' + 'A';
    return (!g_key_prev[vk] && g_key[vk]) ? 1 : 0;
}

void coma_finfo(const char *path) {
    printf("E105 abrir: no se puede (%s). Falta el fichero o permiso denegado (prueba consola de administrador)", path ? path : "?");
    coma_einfo();
    printf("\n");
    fflush(stdout);
    exit(1);
}

#endif

/* Funciones de impresion de decimales con coma (plataforma-independiente) */
/* coma_print_dbl definida en rt_win.c */

void coma_print_dbl0(double val) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", val);
    for (int i = 0; buf[i]; i++)
        if (buf[i] == '.') { buf[i] = ','; break; }
    printf("%s", buf);
    fflush(stdout);
}


void coma_ventana_cerrar(void) {
    if (!g_open) return;
    if (g_hwnd) { DestroyWindow(g_hwnd); g_hwnd = NULL; }
    if (g_hdc) { ReleaseDC(g_hwnd, g_hdc); g_hdc = NULL; }
    g_open = 0;
    if (g_fb) { free(g_fb); g_fb = NULL; }
}
