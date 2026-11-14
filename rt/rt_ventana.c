/* rt_ventana.c — Ventana 2D para .Coma.
   Backends:
     - Windows: Win32 + Vulkan (carga dinámica de vulkan-1.dll, sin OpenGL)
     - Linux/Unix: X11 + Vulkan (carga dinámica con dlopen) o CPU renderer (fallback)
   La IR generada solo llama a coma_ventana_*. El driver elige según --target.
   Un programa sin ventana no enlaza este archivo en absoluto. */
#include "coma_rt.h"
#include "coma_vulkan.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Detecta WSL2 (puede tener socket X11 sin servidor X real). */
static int g_es_wsl2 = 0;
static void detect_wsl2(void) {
    FILE *f = fopen("/proc/version", "r");
    if (!f) return;
    char buf[256];
    if (fgets(buf, sizeof buf, f)) {
        if (strstr(buf, "Microsoft") || strstr(buf, "microsoft")) g_es_wsl2 = 1;
    }
    fclose(f);
}

/* ================================================================
   Estado compartido (todas las plataformas)
   ================================================================ */
static int g_open = 0;
static int g_w = 0, g_h = 0;
static unsigned char g_r = 255, g_g = 255, g_b = 255;
static unsigned char *g_fb = NULL;   /* framebuffer de software (BGRA) */
static int g_use_vulkan = 0;

/* Estado de entrada */
static int g_key[256] = {0};
static int g_mx = 0, g_my = 0;
static int g_mb = 0;
static int g_click_latch = 0;

/* Vulkan compartido (todas las plataformas) */
static VkInstance g_vk_inst = VK_NULL_HANDLE;
static VkPhysicalDevice g_vk_phys = VK_NULL_HANDLE;
static VkDevice g_vk_dev = VK_NULL_HANDLE;
static VkQueue g_vk_queue = VK_NULL_HANDLE;
static VkSwapchainKHR g_vk_swap = VK_NULL_HANDLE;
static VkSurfaceKHR g_vk_surf = VK_NULL_HANDLE;
static VkCommandPool g_vk_pool = VK_NULL_HANDLE;
static VkCommandBuffer g_vk_cmd = VK_NULL_HANDLE;
static VkImage g_vk_img = VK_NULL_HANDLE;
static VkDeviceMemory g_vk_img_mem = VK_NULL_HANDLE;
static VkImageView g_vk_img_view = VK_NULL_HANDLE;
static VkFramebuffer g_vk_fb = VK_NULL_HANDLE;
static VkRenderPass g_vk_rp = VK_NULL_HANDLE;
static VkSemaphore g_vk_sem = VK_NULL_HANDLE;
static VkFence g_vk_fence = VK_NULL_HANDLE;

/* Punteros de función Vulkan (cargados por cada plataforma) */
static PFN_vkGetInstanceProcAddr pfn_vkGetInstanceProcAddr = NULL;
static PFN_vkCreateInstance pfn_vkCreateInstance = NULL;
static PFN_vkDestroyInstance pfn_vkDestroyInstance = NULL;
static PFN_vkEnumeratePhysicalDevices pfn_vkEnumeratePhysicalDevices = NULL;
static PFN_vkGetPhysicalDeviceProperties pfn_vkGetPhysicalDeviceProperties = NULL;
static PFN_vkGetPhysicalDeviceQueueFamilyProperties pfn_vkGetPhysicalDeviceQueueFamilyProperties = NULL;
static PFN_vkGetPhysicalDeviceMemoryProperties pfn_vkGetPhysicalDeviceMemoryProperties = NULL;
static PFN_vkCreateDevice pfn_vkCreateDevice = NULL;
static PFN_vkGetDeviceProcAddr pfn_vkGetDeviceProcAddr = NULL;
static PFN_vkGetDeviceQueue pfn_vkGetDeviceQueue = NULL;
static PFN_vkCreateWin32SurfaceKHR pfn_vkCreateWin32SurfaceKHR = NULL;
static PFN_vkCreateXlibSurfaceKHR pfn_vkCreateXlibSurfaceKHR = NULL;
static PFN_vkGetPhysicalDeviceSurfaceSupportKHR pfn_vkGetPhysicalDeviceSurfaceSupportKHR = NULL;
static PFN_vkCreateSwapchainKHR pfn_vkCreateSwapchainKHR = NULL;
static PFN_vkGetSwapchainImagesKHR pfn_vkGetSwapchainImagesKHR = NULL;
static PFN_vkCreateImageView pfn_vkCreateImageView = NULL;
static PFN_vkCreateRenderPass pfn_vkCreateRenderPass = NULL;
static PFN_vkCreateFramebuffer pfn_vkCreateFramebuffer = NULL;
static PFN_vkCreateCommandPool pfn_vkCreateCommandPool = NULL;
static PFN_vkAllocateCommandBuffers pfn_vkAllocateCommandBuffers = NULL;
static PFN_vkBeginCommandBuffer pfn_vkBeginCommandBuffer = NULL;
static PFN_vkEndCommandBuffer pfn_vkEndCommandBuffer = NULL;
static PFN_vkCmdBindPipeline pfn_vkCmdBindPipeline = NULL;
static PFN_vkCmdDraw pfn_vkCmdDraw = NULL;
static PFN_vkQueueSubmit pfn_vkQueueSubmit = NULL;
static PFN_vkQueuePresentKHR pfn_vkQueuePresentKHR = NULL;
static PFN_vkCreateSemaphore pfn_vkCreateSemaphore = NULL;
static PFN_vkCreateFence pfn_vkCreateFence = NULL;
static PFN_vkDeviceWaitIdle pfn_vkDeviceWaitIdle = NULL;
static PFN_vkDestroySemaphore pfn_vkDestroySemaphore = NULL;
static PFN_vkDestroyFence pfn_vkDestroyFence = NULL;
static PFN_vkDestroyFramebuffer pfn_vkDestroyFramebuffer = NULL;
static PFN_vkDestroyImageView pfn_vkDestroyImageView = NULL;
static PFN_vkDestroySwapchainKHR pfn_vkDestroySwapchainKHR = NULL;
static PFN_vkDestroySurfaceKHR pfn_vkDestroySurfaceKHR = NULL;
static PFN_vkDestroyDevice pfn_vkDestroyDevice = NULL;

/* Framebuffer software: set pixel */
static void fb_set_pixel(int x, int y, unsigned char r, unsigned char g, unsigned char b) {
    if (!g_fb || x < 0 || y < 0 || x >= g_w || y >= g_h) return;
    int idx = (y * g_w + x) * 4;
    g_fb[idx] = b;
    g_fb[idx+1] = g;
    g_fb[idx+2] = r;
    g_fb[idx+3] = 255;
}

static void px(int x, int y) {
    fb_set_pixel(x, y, g_r, g_g, g_b);
}

/* ================================================================
   WINDOWS: declaraciones manuales (sin <windows.h>)
   ================================================================ */
#ifdef _WIN32
typedef void* HMODULE;
typedef void* FARPROC;
typedef void* HWND;
typedef void* HDC;
typedef void* HINSTANCE;
typedef unsigned long DWORD;
typedef int BOOL;
typedef unsigned int UINT;
typedef long LONG;
typedef void* LPVOID;
typedef const char* LPCSTR;
typedef long LRESULT;
typedef unsigned long WPARAM;
typedef long LPARAM;

#define WS_OVERLAPPEDWINDOW 0x00CF0000
#define WS_POPUP 0x80000000
#define WS_VISIBLE 0x10000000
#define CW_USEDEFAULT 0x80000000
#define SW_SHOW 5
#define WM_QUIT 0x0012
#define PM_REMOVE 0x0001
#define CS_HREDRAW 0x0002
#define CS_VREDRAW 0x0001
#define WM_DESTROY 0x0002
#define BI_RGB 0
#define DIB_RGB_COLORS 0
#define SRCCOPY 0x00CC0020
#define WM_PAINT 0x000F

/* BITMAPINFO / BITMAPINFOHEADER para StretchDIBits */
typedef struct { unsigned int biSize; int biWidth; int biHeight; unsigned short biPlanes; unsigned short biBitCount; unsigned int biCompression; unsigned int biSizeImage; int biXPelsPerMeter; int biYPelsPerMeter; unsigned int biClrUsed; unsigned int biClrImportant; } BITMAPINFOHEADER;
typedef struct { BITMAPINFOHEADER bmiHeader; unsigned int bmiColors[3]; } BITMAPINFO;
typedef struct { int left; int top; int right; int bottom; } RECT;

static int (*g_pSetDIBitsToDevice)(HDC,int,int,int,int,int,int,int,int,const void*,const void*,unsigned int) = NULL;

static HMODULE g_user32 = NULL;
static HMODULE g_gdi32 = NULL;
static HMODULE g_vk_lib = NULL;
static HMODULE g_kernel32 = NULL;
static HWND  g_hwnd = NULL;
static HINSTANCE g_hinst = NULL;
static HDC   g_hdc = NULL;

static HWND  (*pCreateWindowExA)(DWORD,LPCSTR,LPCSTR,DWORD,int,int,int,int,HWND,void*,HINSTANCE,void*) = NULL;
static BOOL  (*pRegisterClassA)(const void*) = NULL;
static BOOL  (*pAdjustWindowRect)(void*,DWORD,BOOL) = NULL;
static BOOL  (*pShowWindow)(HWND,int) = NULL;
static BOOL  (*pUpdateWindow)(HWND) = NULL;
static HDC   (*pGetDC)(HWND) = NULL;
static int   (*pReleaseDC)(HWND,HDC) = NULL;
static BOOL  (*pDestroyWindow)(HWND) = NULL;
static void  (*pPostQuitMessage)(int) = NULL;
static BOOL  (*pPeekMessageA)(void*,HWND,UINT,UINT,UINT) = NULL;
static BOOL  (*pTranslateMessage)(const void*) = NULL;
static BOOL  (*pDispatchMessageA)(const void*) = NULL;
static LRESULT(__stdcall *pDefWindowProcA)(HWND,UINT,WPARAM,LPARAM) = NULL;
static int   (*pGetClientRect)(HWND,void*) = NULL;
static HINSTANCE(__stdcall *pGetModuleHandleA)(LPCSTR) = NULL;

static void win_load_user32(void) {
    extern HMODULE __stdcall LoadLibraryA(LPCSTR);
    extern FARPROC __stdcall GetProcAddress(HMODULE, LPCSTR);

    g_user32 = LoadLibraryA("user32.dll");
    g_gdi32 = LoadLibraryA("gdi32.dll");
    g_kernel32 = LoadLibraryA("kernel32.dll");

    if (g_user32) {
        pCreateWindowExA = (HWND(__stdcall*)(DWORD,LPCSTR,LPCSTR,DWORD,int,int,int,int,HWND,void*,HINSTANCE,void*))
                           GetProcAddress(g_user32, "CreateWindowExA");
        pRegisterClassA = (BOOL(__stdcall*)(const void*))GetProcAddress(g_user32, "RegisterClassA");
        pAdjustWindowRect = (BOOL(__stdcall*)(void*,DWORD,BOOL))GetProcAddress(g_user32, "AdjustWindowRect");
        pShowWindow = (BOOL(__stdcall*)(HWND,int))GetProcAddress(g_user32, "ShowWindow");
        pUpdateWindow = (BOOL(__stdcall*)(HWND))GetProcAddress(g_user32, "UpdateWindow");
        pGetDC = (HDC(__stdcall*)(HWND))GetProcAddress(g_user32, "GetDC");
        pReleaseDC = (int(__stdcall*)(HWND,HDC))GetProcAddress(g_user32, "ReleaseDC");
        pDestroyWindow = (BOOL(__stdcall*)(HWND))GetProcAddress(g_user32, "DestroyWindow");
        pPostQuitMessage = (void(__stdcall*)(int))GetProcAddress(g_user32, "PostQuitMessage");
        pPeekMessageA = (BOOL(__stdcall*)(void*,HWND,UINT,UINT,UINT))GetProcAddress(g_user32, "PeekMessageA");
        pTranslateMessage = (BOOL(__stdcall*)(const void*))GetProcAddress(g_user32, "TranslateMessage");
        pDispatchMessageA = (BOOL(__stdcall*)(const void*))GetProcAddress(g_user32, "DispatchMessageA");
        pDefWindowProcA = (LRESULT(__stdcall*)(HWND,UINT,WPARAM,LPARAM))GetProcAddress(g_user32, "DefWindowProcA");
        pGetClientRect = (int(__stdcall*)(HWND,void*))GetProcAddress(g_user32, "GetClientRect");
    }
    if (g_kernel32) {
        pGetModuleHandleA = (HINSTANCE(__stdcall*)(LPCSTR))GetProcAddress(g_kernel32, "GetModuleHandleA");
    }
    if (g_gdi32) {
        g_pSetDIBitsToDevice = (int (*)(HDC,int,int,int,int,int,int,int,int,const void*,const void*,unsigned int))
                               GetProcAddress(g_gdi32, "SetDIBitsToDevice");
    }
}

static void win_load_vulkan(void) {
    extern HMODULE __stdcall LoadLibraryA(LPCSTR);
    extern FARPROC __stdcall GetProcAddress(HMODULE, LPCSTR);

    FILE *vkdbg = fopen("D:\\Temp\\kilo\\vulkan_debug.txt", "w");
    if (vkdbg) {
        fprintf(vkdbg, "vulkan debug start\n");
        fflush(vkdbg);
    }

    g_vk_lib = LoadLibraryA("vulkan-1-1-0-65-1.dll");
    if (!g_vk_lib) g_vk_lib = LoadLibraryA("vulkan-1.dll");
    if (vkdbg) { fprintf(vkdbg, "vulkan-1.dll = %p\n", (void*)g_vk_lib); fflush(vkdbg); }
    if (!g_vk_lib) { if (vkdbg) fclose(vkdbg); return; }
    pfn_vkGetInstanceProcAddr = (PFN_vkGetInstanceProcAddr)GetProcAddress(g_vk_lib, "vkGetInstanceProcAddr");
    if (vkdbg) { fprintf(vkdbg, "vkGetInstanceProcAddr = %p\n", (void*)pfn_vkGetInstanceProcAddr); fflush(vkdbg); }
    if (!pfn_vkGetInstanceProcAddr) { if (vkdbg) fclose(vkdbg); return; }
    /* Solo funciones de nivel global (se pueden obtener con instance NULL) */
    pfn_vkCreateInstance = (PFN_vkCreateInstance)pfn_vkGetInstanceProcAddr(NULL, "vkCreateInstance");
    pfn_vkDestroyInstance = (PFN_vkDestroyInstance)pfn_vkGetInstanceProcAddr(NULL, "vkDestroyInstance");
    if (vkdbg) { fprintf(vkdbg, "vkCreateInstance=%p vkDestroyInstance=%p\n",
             (void*)pfn_vkCreateInstance, (void*)pfn_vkDestroyInstance); fflush(vkdbg); fclose(vkdbg); }
}

/* Carga funciones de nivel de instancia (después de crear VkInstance) */
static void win_load_vulkan_instance(void) {
    FILE *vkdbg = fopen("D:\\Temp\\kilo\\vulkan_debug.txt", "a");
    if (!g_vk_inst) { if (vkdbg) fclose(vkdbg); return; }
    pfn_vkEnumeratePhysicalDevices = (PFN_vkEnumeratePhysicalDevices)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkEnumeratePhysicalDevices");
    pfn_vkGetPhysicalDeviceProperties = (PFN_vkGetPhysicalDeviceProperties)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkGetPhysicalDeviceProperties");
    pfn_vkGetPhysicalDeviceQueueFamilyProperties = (PFN_vkGetPhysicalDeviceQueueFamilyProperties)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkGetPhysicalDeviceQueueFamilyProperties");
    pfn_vkGetPhysicalDeviceMemoryProperties = (PFN_vkGetPhysicalDeviceMemoryProperties)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkGetPhysicalDeviceMemoryProperties");
    pfn_vkCreateDevice = (PFN_vkCreateDevice)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateDevice");
    pfn_vkGetDeviceProcAddr = (PFN_vkGetDeviceProcAddr)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkGetDeviceProcAddr");
    pfn_vkGetDeviceQueue = (PFN_vkGetDeviceQueue)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkGetDeviceQueue");
    pfn_vkCreateWin32SurfaceKHR = (PFN_vkCreateWin32SurfaceKHR)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateWin32SurfaceKHR");
    pfn_vkCreateSwapchainKHR = (PFN_vkCreateSwapchainKHR)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateSwapchainKHR");
    pfn_vkGetSwapchainImagesKHR = (PFN_vkGetSwapchainImagesKHR)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkGetSwapchainImagesKHR");
    pfn_vkCreateImageView = (PFN_vkCreateImageView)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateImageView");
    pfn_vkCreateRenderPass = (PFN_vkCreateRenderPass)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateRenderPass");
    pfn_vkCreateFramebuffer = (PFN_vkCreateFramebuffer)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateFramebuffer");
    pfn_vkCreateCommandPool = (PFN_vkCreateCommandPool)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateCommandPool");
    pfn_vkAllocateCommandBuffers = (PFN_vkAllocateCommandBuffers)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkAllocateCommandBuffers");
    pfn_vkBeginCommandBuffer = (PFN_vkBeginCommandBuffer)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkBeginCommandBuffer");
    pfn_vkEndCommandBuffer = (PFN_vkEndCommandBuffer)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkEndCommandBuffer");
    pfn_vkCmdBindPipeline = (PFN_vkCmdBindPipeline)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCmdBindPipeline");
    pfn_vkCmdDraw = (PFN_vkCmdDraw)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCmdDraw");
    pfn_vkQueueSubmit = (PFN_vkQueueSubmit)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkQueueSubmit");
    pfn_vkQueuePresentKHR = (PFN_vkQueuePresentKHR)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkQueuePresentKHR");
    pfn_vkCreateSemaphore = (PFN_vkCreateSemaphore)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateSemaphore");
    pfn_vkCreateFence = (PFN_vkCreateFence)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkCreateFence");
    pfn_vkDeviceWaitIdle = (PFN_vkDeviceWaitIdle)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDeviceWaitIdle");
    pfn_vkDestroySemaphore = (PFN_vkDestroySemaphore)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDestroySemaphore");
    pfn_vkDestroyFence = (PFN_vkDestroyFence)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDestroyFence");
    pfn_vkDestroyFramebuffer = (PFN_vkDestroyFramebuffer)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDestroyFramebuffer");
    pfn_vkDestroyImageView = (PFN_vkDestroyImageView)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDestroyImageView");
    pfn_vkDestroySwapchainKHR = (PFN_vkDestroySwapchainKHR)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDestroySwapchainKHR");
    pfn_vkDestroySurfaceKHR = (PFN_vkDestroySurfaceKHR)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDestroySurfaceKHR");
    pfn_vkDestroyDevice = (PFN_vkDestroyDevice)pfn_vkGetInstanceProcAddr(g_vk_inst, "vkDestroyDevice");
    if (vkdbg) { fprintf(vkdbg, "vulkan instance functions loaded\n"); fflush(vkdbg); fclose(vkdbg); }
}
#endif

/* ================================================================
   LINUX/UNIX: declaraciones manuales (coma_x11.h, coma_vulkan.h)
   Carga dinámica con dlopen (sin -lX11)
   ================================================================ */
#ifndef _WIN32
#include <dlfcn.h>
#include "coma_x11.h"
#include "coma_vulkan.h"

static void *g_x11_lib = NULL;
static void *g_vk_lib = NULL;
static Display *g_dpy = NULL;
static Window g_xwin = 0;
static GC g_xgc = 0;
static XImage *g_ximg = NULL;

static Display *(*pfn_XOpenDisplay)(const char*) = NULL;
static int (*pfn_DefaultScreen)(Display*) = NULL;
static Window (*pfn_RootWindow)(Display*, int) = NULL;
static Window (*pfn_XCreateWindow)(Display*,Window,int,int,unsigned int,unsigned int,unsigned int,int,unsigned int,void*,unsigned long,void*) = NULL;
static int (*pfn_XStoreName)(Display*,Window,const char*) = NULL;
static int (*pfn_XMapWindow)(Display*,Window) = NULL;
static int (*pfn_XFlush)(Display*) = NULL;
static int (*pfn_XPending)(Display*) = NULL;
static int (*pfn_XNextEvent)(Display*,XEvent*) = NULL;
static int (*pfn_XCloseDisplay)(Display*) = NULL;
static int (*pfn_XDestroyImage)(XImage*) = NULL;
static int (*pfn_XFreeGC)(Display*,GC) = NULL;
static int (*pfn_XDestroyWindow)(Display*,Window) = NULL;
static int (*pfn_XPutImage)(Display*,Window,GC,XImage*,int,int,int,int,unsigned int,unsigned int) = NULL;
static GC (*pfn_XCreateGC)(Display*,Window,unsigned long,void*) = NULL;
static XImage* (*pfn_XCreateImage)(Display*,void*,unsigned int,int,int,char*,unsigned int,unsigned int,int,int) = NULL;
static KeySym (*pfn_XkbKeycodeToKeysym)(Display*,unsigned int,int,int) = NULL;
static int (*pfn_XConnectionNumber)(Display*) = NULL;

static void linux_load_x11(void) {
    /* Binario estático musl: dlopen no funciona. Usamos dlsym(RTLD_DEFAULT)
       para resolver los símbolos de libX11/libvulkan que zig cc enlazó directo. */
    g_x11_lib = (void*)1;
    pfn_XOpenDisplay = (Display*(*)(const char*))dlsym(RTLD_DEFAULT, "XOpenDisplay");
    pfn_DefaultScreen = (int(*)(Display*))dlsym(RTLD_DEFAULT, "DefaultScreen");
    pfn_RootWindow = (Window(*)(Display*,int))dlsym(RTLD_DEFAULT, "RootWindow");
    pfn_XCreateWindow = (Window(*)(Display*,Window,int,int,unsigned int,unsigned int,unsigned int,int,unsigned int,void*,unsigned long,void*))
                        dlsym(RTLD_DEFAULT, "XCreateWindow");
    pfn_XStoreName = (int(*)(Display*,Window,const char*))dlsym(RTLD_DEFAULT, "XStoreName");
    pfn_XMapWindow = (int(*)(Display*,Window))dlsym(RTLD_DEFAULT, "XMapWindow");
    pfn_XFlush = (int(*)(Display*))dlsym(RTLD_DEFAULT, "XFlush");
    pfn_XPending = (int(*)(Display*))dlsym(RTLD_DEFAULT, "XPending");
    pfn_XNextEvent = (int(*)(Display*,XEvent*))dlsym(RTLD_DEFAULT, "XNextEvent");
    pfn_XCloseDisplay = (int(*)(Display*))dlsym(RTLD_DEFAULT, "XCloseDisplay");
    pfn_XDestroyImage = (int(*)(XImage*))dlsym(RTLD_DEFAULT, "XDestroyImage");
    pfn_XFreeGC = (int(*)(Display*,GC))dlsym(RTLD_DEFAULT, "XFreeGC");
    pfn_XDestroyWindow = (int(*)(Display*,Window))dlsym(RTLD_DEFAULT, "XDestroyWindow");
    pfn_XPutImage = (int(*)(Display*,Window,GC,XImage*,int,int,int,int,unsigned int,unsigned int))
                    dlsym(RTLD_DEFAULT, "XPutImage");
    pfn_XCreateGC = (GC(*)(Display*,Window,unsigned long,void*))dlsym(RTLD_DEFAULT, "XCreateGC");
    pfn_XCreateImage = (XImage*(*)(Display*,void*,unsigned int,int,int,char*,unsigned int,unsigned int,int,int))
                       dlsym(RTLD_DEFAULT, "XCreateImage");
    pfn_XkbKeycodeToKeysym = (KeySym(*)(Display*,unsigned int,int,int))dlsym(RTLD_DEFAULT, "XkbKeycodeToKeysym");
    pfn_XConnectionNumber = (int(*)(Display*))dlsym(RTLD_DEFAULT, "XConnectionNumber");
}

static void linux_load_vulkan(void) {
    g_vk_lib = (void*)1;
    pfn_vkGetInstanceProcAddr = (PFN_vkGetInstanceProcAddr)dlsym(RTLD_DEFAULT, "vkGetInstanceProcAddr");
    if (!pfn_vkGetInstanceProcAddr) return;
    pfn_vkCreateInstance = (PFN_vkCreateInstance)pfn_vkGetInstanceProcAddr(NULL, "vkCreateInstance");
    pfn_vkDestroyInstance = (PFN_vkDestroyInstance)pfn_vkGetInstanceProcAddr(NULL, "vkDestroyInstance");
    pfn_vkEnumeratePhysicalDevices = (PFN_vkEnumeratePhysicalDevices)pfn_vkGetInstanceProcAddr(NULL, "vkEnumeratePhysicalDevices");
    pfn_vkGetPhysicalDeviceProperties = (PFN_vkGetPhysicalDeviceProperties)pfn_vkGetInstanceProcAddr(NULL, "vkGetPhysicalDeviceProperties");
    pfn_vkGetPhysicalDeviceQueueFamilyProperties = (PFN_vkGetPhysicalDeviceQueueFamilyProperties)pfn_vkGetInstanceProcAddr(NULL, "vkGetPhysicalDeviceQueueFamilyProperties");
    pfn_vkGetPhysicalDeviceMemoryProperties = (PFN_vkGetPhysicalDeviceMemoryProperties)pfn_vkGetInstanceProcAddr(NULL, "vkGetPhysicalDeviceMemoryProperties");
    pfn_vkCreateDevice = (PFN_vkCreateDevice)pfn_vkGetInstanceProcAddr(NULL, "vkCreateDevice");
    pfn_vkGetDeviceProcAddr = (PFN_vkGetDeviceProcAddr)pfn_vkGetInstanceProcAddr(NULL, "vkGetDeviceProcAddr");
    pfn_vkGetDeviceQueue = (PFN_vkGetDeviceQueue)pfn_vkGetInstanceProcAddr(NULL, "vkGetDeviceQueue");
    pfn_vkCreateXlibSurfaceKHR = (PFN_vkCreateXlibSurfaceKHR)pfn_vkGetInstanceProcAddr(NULL, "vkCreateXlibSurfaceKHR");
    pfn_vkGetPhysicalDeviceSurfaceSupportKHR = (PFN_vkGetPhysicalDeviceSurfaceSupportKHR)pfn_vkGetInstanceProcAddr(NULL, "vkGetPhysicalDeviceSurfaceSupportKHR");
    pfn_vkCreateSwapchainKHR = (PFN_vkCreateSwapchainKHR)pfn_vkGetInstanceProcAddr(NULL, "vkCreateSwapchainKHR");
    pfn_vkGetSwapchainImagesKHR = (PFN_vkGetSwapchainImagesKHR)pfn_vkGetInstanceProcAddr(NULL, "vkGetSwapchainImagesKHR");
    pfn_vkCreateImageView = (PFN_vkCreateImageView)pfn_vkGetInstanceProcAddr(NULL, "vkCreateImageView");
    pfn_vkCreateRenderPass = (PFN_vkCreateRenderPass)pfn_vkGetInstanceProcAddr(NULL, "vkCreateRenderPass");
    pfn_vkCreateFramebuffer = (PFN_vkCreateFramebuffer)pfn_vkGetInstanceProcAddr(NULL, "vkCreateFramebuffer");
    pfn_vkCreateCommandPool = (PFN_vkCreateCommandPool)pfn_vkGetInstanceProcAddr(NULL, "vkCreateCommandPool");
    pfn_vkAllocateCommandBuffers = (PFN_vkAllocateCommandBuffers)pfn_vkGetInstanceProcAddr(NULL, "vkAllocateCommandBuffers");
    pfn_vkBeginCommandBuffer = (PFN_vkBeginCommandBuffer)pfn_vkGetInstanceProcAddr(NULL, "vkBeginCommandBuffer");
    pfn_vkEndCommandBuffer = (PFN_vkEndCommandBuffer)pfn_vkGetInstanceProcAddr(NULL, "vkEndCommandBuffer");
    pfn_vkCmdBindPipeline = (PFN_vkCmdBindPipeline)pfn_vkGetInstanceProcAddr(NULL, "vkCmdBindPipeline");
    pfn_vkCmdDraw = (PFN_vkCmdDraw)pfn_vkGetInstanceProcAddr(NULL, "vkCmdDraw");
    pfn_vkQueueSubmit = (PFN_vkQueueSubmit)pfn_vkGetInstanceProcAddr(NULL, "vkQueueSubmit");
    pfn_vkQueuePresentKHR = (PFN_vkQueuePresentKHR)pfn_vkGetInstanceProcAddr(NULL, "vkQueuePresentKHR");
    pfn_vkCreateSemaphore = (PFN_vkCreateSemaphore)pfn_vkGetInstanceProcAddr(NULL, "vkCreateSemaphore");
    pfn_vkCreateFence = (PFN_vkCreateFence)pfn_vkGetInstanceProcAddr(NULL, "vkCreateFence");
    pfn_vkDeviceWaitIdle = (PFN_vkDeviceWaitIdle)pfn_vkGetInstanceProcAddr(NULL, "vkDeviceWaitIdle");
    pfn_vkDestroySemaphore = (PFN_vkDestroySemaphore)pfn_vkGetInstanceProcAddr(NULL, "vkDestroySemaphore");
    pfn_vkDestroyFence = (PFN_vkDestroyFence)pfn_vkGetInstanceProcAddr(NULL, "vkDestroyFence");
    pfn_vkDestroyFramebuffer = (PFN_vkDestroyFramebuffer)pfn_vkGetInstanceProcAddr(NULL, "vkDestroyFramebuffer");
    pfn_vkDestroyImageView = (PFN_vkDestroyImageView)pfn_vkGetInstanceProcAddr(NULL, "vkDestroyImageView");
    pfn_vkDestroySwapchainKHR = (PFN_vkDestroySwapchainKHR)pfn_vkGetInstanceProcAddr(NULL, "vkDestroySwapchainKHR");
    pfn_vkDestroySurfaceKHR = (PFN_vkDestroySurfaceKHR)pfn_vkGetInstanceProcAddr(NULL, "vkDestroySurfaceKHR");
    pfn_vkDestroyDevice = (PFN_vkDestroyDevice)pfn_vkGetInstanceProcAddr(NULL, "vkDestroyDevice");
}
#endif

/* ================================================================
   coma_ventana_abrir
   ================================================================ */
void coma_ventana_abrir(int w, int h, const char *title) {
    if (g_open) return;
    if (w <= 0 || h <= 0) { w = 800; h = 600; }
    if (!title) title = ".Coma";
    g_w = w; g_h = h;
    g_open = 1;
    { extern void __stdcall FreeConsole(void); FreeConsole(); }

    g_fb = (unsigned char *)malloc((size_t)g_w * g_h * 4);
    if (!g_fb) { printf("E202 ventana framebuffer\n"); exit(1); }
    memset(g_fb, 0, (size_t)g_w * g_h * 4);

#ifdef _WIN32
    win_load_user32();
    win_load_vulkan();
    printf("ventana: cargando librerías Win32... user32=%p gdi32=%p vulkan=%p\n",
           (void*)g_user32, (void*)g_gdi32, (void*)g_vk_lib);
    if (!pCreateWindowExA || !pRegisterClassA || !pAdjustWindowRect || !pShowWindow || !pGetDC || !pReleaseDC || !pDestroyWindow || !pGetModuleHandleA || !g_pSetDIBitsToDevice) {
        printf("ventana: ERROR - funciones Win32 no cargadas\n");
        g_use_vulkan = 0;
        return;
    }
    g_hinst = pGetModuleHandleA(NULL);
    if (!g_hinst) { printf("ventana: ERROR - GetModuleHandleA falló\n"); g_use_vulkan = 0; return; }

    /* Registrar clase de ventana */
    if (pRegisterClassA) {
        struct { unsigned int style; void* lpfn; int cbClsExtra; int cbWndExtra; void* hInstance; void* hIcon; void* hCursor; void* hbrBackground; const char* lpszMenuName; const char* lpszClassName; } wc;
        memset(&wc, 0, sizeof(wc));
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfn = (void*)pDefWindowProcA;
        wc.hInstance = g_hinst;
        wc.lpszClassName = "ComaWindowClass";
        pRegisterClassA(&wc);
    }

    /* Calcular tamaño de ventana para que el área cliente sea exactamente w x h */
    int win_w = w, win_h = h;
    if (pAdjustWindowRect) {
        RECT rc;
        rc.left = 0; rc.top = 0; rc.right = w; rc.bottom = h;
        pAdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, 0);
        win_w = rc.right - rc.left;
        win_h = rc.bottom - rc.top;
    }

    g_hwnd = pCreateWindowExA(0, "ComaWindowClass", title, WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                              CW_USEDEFAULT, CW_USEDEFAULT, win_w, win_h, NULL, NULL, g_hinst, NULL);
    if (!g_hwnd) { printf("ventana: ERROR - CreateWindowExA falló\n"); g_use_vulkan = 0; return; }
    pShowWindow(g_hwnd, SW_SHOW);
    pUpdateWindow(g_hwnd);
    g_hdc = pGetDC(g_hwnd);
    if (!g_hdc) { pDestroyWindow(g_hwnd); g_hwnd = NULL; g_use_vulkan = 0; return; }

    /* Inicializar Vulkan */
    {
        int force_gdi = 0, force_vk = 0;
        const char *envr = getenv("COMA_RENDERER");
        if (envr) {
            if (strcmp(envr, "gdi") == 0) force_gdi = 1;
            else if (strcmp(envr, "vulkan") == 0) force_vk = 1;
        }
        extern char* GetCommandLineA(void);
        const char *cmdline = GetCommandLineA();
        if (cmdline) {
            if (strstr(cmdline, "--gdi")) force_gdi = 1;
            if (strstr(cmdline, "--vulkan")) force_vk = 1;
        }
        if (!force_gdi && !force_vk) {
            int chosen = 0;
            int frames = 0;
            while (!chosen && g_open) {
                coma_ventana_limpiar();
                coma_ventana_color(220, 220, 220);
                coma_ventana_rotulo(110, 60, "Elige renderer:");
                coma_ventana_color(0, 120, 255);
                coma_ventana_rectangulo(60, 140, 130, 60);
                coma_ventana_color(255, 255, 255);
                coma_ventana_rotulo(95, 160, "Vulkan");
                coma_ventana_color(0, 180, 100);
                coma_ventana_rectangulo(210, 140, 130, 60);
                coma_ventana_color(255, 255, 255);
                coma_ventana_rotulo(255, 160, "GDI");
                if (g_pSetDIBitsToDevice && g_hdc && g_fb) {
                    BITMAPINFO bmi; memset(&bmi, 0, sizeof(bmi));
                    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
                    bmi.bmiHeader.biWidth = g_w; bmi.bmiHeader.biHeight = -g_h;
                    bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 32;
                    bmi.bmiHeader.biCompression = BI_RGB;
                    g_pSetDIBitsToDevice(g_hdc, 0, 0, g_w, g_h, 0, 0, 0, g_h, g_fb, &bmi, DIB_RGB_COLORS);
                }
                char msg[48];
                while (pPeekMessageA && pPeekMessageA(msg, NULL, 0, 0, PM_REMOVE)) {
                    unsigned int message = *(unsigned int*)((char*)msg + 8);
                    if (message == 0x0012) { g_open = 0; chosen = 2; }
                    else if (message == 0x0200) {
                        long long lp = *(long long*)((char*)msg + 24);
                        g_mx = (int)(lp & 0xFFFF); g_my = (int)((lp >> 16) & 0xFFFF);
                    } else if (message == 0x0201) {
                        long long lp = *(long long*)((char*)msg + 24);
                        g_mx = (int)(lp & 0xFFFF); g_my = (int)((lp >> 16) & 0xFFFF);
                        g_mb |= 1;
                    } else if (message == 0x0202) {
                        g_mb &= ~1;
                        if (g_mx >= 60 && g_mx <= 190 && g_my >= 140 && g_my <= 200) chosen = 1;
                        else if (g_mx >= 210 && g_mx <= 340 && g_my >= 140 && g_my <= 200) chosen = 2;
                    } else {
                        if (pTranslateMessage) pTranslateMessage(msg);
                        if (pDispatchMessageA) pDispatchMessageA(msg);
                    }
                }
                if (chosen) break;
                frames++;
                if (frames > 300) { chosen = 1; break; }
                coma_sleep_ms(10);
            }
            if (chosen == 1) force_vk = 1;
            else force_gdi = 1;
        }
        printf("ventana: cmdline=%s\n", cmdline ? cmdline : "(null)"); fflush(stdout);
        printf("ventana: force_gdi=%d force_vk=%d\n", force_gdi, force_vk); fflush(stdout);
        if (force_gdi) {
            printf("ventana: renderer forzado a GDI\n");
        } else {
            HMODULE vklib = LoadLibraryA("vulkan-1-1-0-65-1.dll");
            if (!vklib) vklib = LoadLibraryA("vulkan-1.dll");
        if (vklib) {
            PFN_vkGetInstanceProcAddr gipa = (PFN_vkGetInstanceProcAddr)GetProcAddress(vklib, "vkGetInstanceProcAddr");
            if (gipa) {
                const char* const exts[] = { "VK_KHR_surface", "VK_KHR_win32_surface" };
                VkApplicationInfo ai = { VK_STRUCTURE_TYPE_APPLICATION_INFO, NULL, ".Coma", VK_MAKE_VERSION(1,0,0), ".Coma", VK_MAKE_VERSION(1,0,0), VK_API_VERSION_1_0 };
                VkInstanceCreateInfo ici = { VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, NULL, 0, &ai, 0, NULL, 2, exts };
                VkInstance inst = NULL;
                PFN_vkCreateInstance ci = (PFN_vkCreateInstance)gipa(NULL, "vkCreateInstance");
                if (ci && ci(&ici, NULL, &inst) == VK_SUCCESS) {
                    PFN_vkCreateWin32SurfaceKHR cs = (PFN_vkCreateWin32SurfaceKHR)gipa(inst, "vkCreateWin32SurfaceKHR");
                    if (cs) {
                        VkPhysicalDevice phys = NULL;
                        uint32_t gpuCount = 0;
                        PFN_vkEnumeratePhysicalDevices epd = (PFN_vkEnumeratePhysicalDevices)gipa(inst, "vkEnumeratePhysicalDevices");
                        if (epd) { epd(inst, &gpuCount, NULL); }
                        if (gpuCount > 0) {
                            VkPhysicalDevice gpus[16];
                            epd(inst, &gpuCount, gpus);
                            phys = gpus[0];
                        }
                        if (phys) {
                            VkWin32SurfaceCreateInfoKHR si = { VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR, NULL, 0, g_hinst, g_hwnd };
                            VkSurfaceKHR surf = 0;
                            VkResult _sr = cs(inst, &si, NULL, &surf);
                            if (_sr == VK_SUCCESS) {
                                g_vk_inst = inst;
                                g_vk_phys = phys;
                                g_vk_surf = surf;
                                g_use_vulkan = 1;
                                printf("ventana: Vulkan inicializado en Windows\n");
                            }
                        }
                    }
                }
            }
        }
    }
    }
    if (!g_use_vulkan) {
        printf("ventana: Vulkan no disponible, usando GDI (sin OpenGL)\n");
    }
    printf("ventana: ventana Win32 creada (%dx%d) en %p\n", w, h, (void*)g_hwnd);
    { FILE* _f = fopen("D:/Temp/kilo/abrir.log","a"); if (_f) { fprintf(_f, "opened %dx%d\n", w, h); fflush(_f); fclose(_f); } }
#else
    detect_wsl2();
    /* Siempre intentar X11 (Xvfb/Xming/VcXsrv pueden estar disponibles). */
    linux_load_x11();
    if (pfn_XOpenDisplay && pfn_DefaultScreen && pfn_RootWindow && pfn_XCreateWindow &&
        pfn_XStoreName && pfn_XMapWindow && pfn_XFlush) {
        g_dpy = pfn_XOpenDisplay(NULL);
        if (g_dpy) {
            int screen = pfn_DefaultScreen(g_dpy);
            XSetWindowAttributes wa;
            wa.event_mask = ExposureMask | KeyPressMask | KeyReleaseMask |
                            ButtonPressMask | ButtonReleaseMask | PointerMotionMask |
                            StructureNotifyMask;
            g_xwin = pfn_XCreateWindow(g_dpy, pfn_RootWindow(g_dpy, screen),
                                       0, 0, g_w, g_h, 0,
                                       CopyFromParent, InputOutput,
                                       CopyFromParent,
                                       CWEventMask, &wa);
            pfn_XStoreName(g_dpy, g_xwin, title);
            pfn_XMapWindow(g_dpy, g_xwin);
            pfn_XFlush(g_dpy);
        }
    }
    if (!g_dpy) {
        g_use_vulkan = 0;
    } else {
        linux_load_vulkan();
        if (pfn_vkCreateInstance && pfn_vkCreateXlibSurfaceKHR) {
            g_use_vulkan = 1;
        } else {
            g_use_vulkan = 0;  /* CPU renderer fallback */
        }
    }
    #endif
}

/* ================================================================
   Dibujo CPU renderer
   ================================================================ */
void coma_ventana_limpiar(void) {
    if (!g_open) return;
    if (g_fb) memset(g_fb, 0, (size_t)g_w * g_h * 4);
}

void coma_ventana_color(int r, int g, int b) {
    g_r = (unsigned char)r; g_g = (unsigned char)g; g_b = (unsigned char)b;
}

void coma_ventana_rectangulo(int x, int y, int w, int h) {
    if (!g_open) return;
    if (g_fb) {
        int x0 = x, y0 = y, x1 = x + w, y1 = y + h;
        if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0;
        if (x1 > g_w) x1 = g_w; if (y1 > g_h) y1 = g_h;
        for (int yy = y0; yy < y1; yy++)
            for (int xx = x0; xx < x1; xx++) fb_set_pixel(xx, yy, g_r, g_g, g_b);
    }
}

void coma_ventana_circulo(int cx, int cy, int r) {
    if (!g_open) return;
    if (g_fb) {
        int x0 = cx - r, y0 = cy - r, x1 = cx + r, y1 = cy + r;
        if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0;
        if (x1 > g_w) x1 = g_w; if (y1 > g_h) y1 = g_h;
        int r2 = r * r;
        for (int yy = y0; yy < y1; yy++) {
            for (int xx = x0; xx < x1; xx++) {
                int dx = xx - cx, dy = yy - cy;
                if (dx*dx + dy*dy <= r2) fb_set_pixel(xx, yy, g_r, g_g, g_b);
            }
        }
    }
}

void coma_ventana_linea(int x1, int y1, int x2, int y2) {
    if (!g_open) return;
    if (g_fb) {
        int dx = abs(x2 - x1), dy = abs(y2 - y1);
        int sx = (x1 < x2) ? 1 : -1;
        int sy = (y1 < y2) ? 1 : -1;
        int err = dx - dy;
        int x = x1, y = y1;
        while (1) {
            if (x >= 0 && x < g_w && y >= 0 && y < g_h) fb_set_pixel(x, y, g_r, g_g, g_b);
            if (x == x2 && y == y2) break;
            int e2 = 2 * err;
            if (e2 > -dy) { err -= dy; x += sx; }
            if (e2 < dx) { err += dx; y += sy; }
        }
    }
}

void coma_ventana_rotulo(int x, int y, const char *txt) {
    if (!g_open || !txt) return;
    if (g_fb) {
        extern const unsigned char *coma_font8x8_get(int c);
        for (int i = 0; txt[i]; i++) {
            const unsigned char *font = coma_font8x8_get((unsigned char)txt[i]);
            if (!font) continue;
            for (int row = 0; row < 8; row++) {
                unsigned char bits = font[row];
                for (int col = 0; col < 8; col++) {
                    if (bits & (1 << (7 - col))) {
                        int px = x + i * 8 + col;
                        int py = y + row;
                        if (px >= 0 && px < g_w && py >= 0 && py < g_h)
                            fb_set_pixel(px, py, g_r, g_g, g_b);
                    }
                }
            }
        }
    }
}

/* ================================================================
   coma_ventana_voltear
   ================================================================ */
void coma_ventana_voltear(void) {
    if (!g_open) return;
#ifdef _WIN32
    /* Presentar framebuffer */
    if (g_pSetDIBitsToDevice && g_hdc && g_fb) {
        BITMAPINFO bmi;
        memset(&bmi, 0, sizeof(bmi));
        bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bmi.bmiHeader.biWidth = g_w;
        bmi.bmiHeader.biHeight = -g_h;
        bmi.bmiHeader.biPlanes = 1;
        bmi.bmiHeader.biBitCount = 32;
        bmi.bmiHeader.biCompression = BI_RGB;
        g_pSetDIBitsToDevice(g_hdc, 0, 0, g_w, g_h, 0, 0, 0, g_h, g_fb, &bmi, DIB_RGB_COLORS);
    }
    /* Drenar mensajes pendientes sin bloquear */
    {
        char msg[48];
        while (pPeekMessageA && pPeekMessageA(msg, NULL, 0, 0, PM_REMOVE)) {
            unsigned int message = *(unsigned int*)((char*)msg + 8);
            if (message == 0x0012) { g_open = 0; }
            else if (message == 0x000F) {
                if (g_pSetDIBitsToDevice && g_hdc && g_fb) {
                    BITMAPINFO bmi2;
                    memset(&bmi2, 0, sizeof(bmi2));
                    bmi2.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
                    bmi2.bmiHeader.biWidth = g_w;
                    bmi2.bmiHeader.biHeight = -g_h;
                    bmi2.bmiHeader.biPlanes = 1;
                    bmi2.bmiHeader.biBitCount = 32;
                    bmi2.bmiHeader.biCompression = BI_RGB;
                    g_pSetDIBitsToDevice(g_hdc, 0, 0, g_w, g_h, 0, 0, 0, g_h, g_fb, &bmi2, DIB_RGB_COLORS);
                }
            } else {
                unsigned int m = message;
                if (m == 0x0200) {
                    long long lp = *(long long*)((char*)msg + 24);
                    g_mx = (int)(lp & 0xFFFF); g_my = (int)((lp >> 16) & 0xFFFF);
                } else if (m == 0x0201) {
                    long long lp = *(long long*)((char*)msg + 24);
                    g_mx = (int)(lp & 0xFFFF); g_my = (int)((lp >> 16) & 0xFFFF);
                    g_mb |= 1;
                    g_click_latch = 1;
                } else if (m == 0x0202) {
                    g_mb &= ~1;
                } else if (m == 0x0100) {
                    int vk = (int)(*(long long*)((char*)msg + 16) & 0xFF);
                    if (vk >= 0 && vk < 256) g_key[vk] = 1;
                } else if (m == 0x0101) {
                    int vk = (int)(*(long long*)((char*)msg + 16) & 0xFF);
                    if (vk >= 0 && vk < 256) g_key[vk] = 0;
                } else {
                    if (pTranslateMessage) pTranslateMessage(msg);
                    if (pDispatchMessageA) pDispatchMessageA(msg);
                }
            }
        }
    }
#else
    if (g_use_vulkan) {
        if (pfn_XPending && pfn_XNextEvent && g_dpy) {
            XEvent ev;
            while (pfn_XPending(g_dpy)) {
                pfn_XNextEvent(g_dpy, &ev);
                if (ev.type == ClientMessage) g_open = 0;
            }
        }
    } else {
        if (!g_dpy) {
            if (g_es_wsl2) {
                printf("ventana: WSL2 detectado pero sin X11 (arranca Xvfb: Xvfb :99 -screen 0 1280x1024x24)\n");
                coma_sleep_ms(3000);
                return;
            }
            g_dpy = pfn_XOpenDisplay(NULL);
            if (!g_dpy) {
                printf("ventana: no hay servidor X11 disponible (necesitas Xvfb/Xming/VcXsrv)\n");
                coma_sleep_ms(3000);
                return;
            }
            int screen = pfn_DefaultScreen(g_dpy);
            XSetWindowAttributes wa;
            wa.event_mask = ExposureMask | KeyPressMask | KeyReleaseMask |
                            ButtonPressMask | ButtonReleaseMask | PointerMotionMask |
                            StructureNotifyMask;
            g_xwin = pfn_XCreateWindow(g_dpy, pfn_RootWindow(g_dpy, screen),
                                       0, 0, g_w, g_h, 0,
                                       CopyFromParent, InputOutput,
                                       CopyFromParent,
                                       CWEventMask, &wa);
            pfn_XStoreName(g_dpy, g_xwin, ".Coma");
            pfn_XMapWindow(g_dpy, g_xwin);
            g_xgc = pfn_XCreateGC(g_dpy, g_xwin, 0, NULL);
            g_ximg = pfn_XCreateImage(g_dpy, CopyFromParent, 24, ZPixmap, 0,
                                      (char *)g_fb, g_w, g_h, 32, 0);
        }
        int frames = 0;
        while (g_open && pfn_XPending && pfn_XNextEvent && pfn_XPutImage && pfn_XFlush && frames < 500) {
            XEvent ev;
            while (pfn_XPending(g_dpy)) {
                pfn_XNextEvent(g_dpy, &ev);
                switch (ev.type) {
                case KeyPress: {
                    KeySym ks = pfn_XkbKeycodeToKeysym(g_dpy, ev.xkey.keycode, 0, 0);
                    if (ks >= 'a' && ks <= 'z') ks = ks - 'a' + 'A';
                    if (ks < 256) g_key[ks] = 1;
                    break;
                }
                case KeyRelease: {
                    KeySym ks = pfn_XkbKeycodeToKeysym(g_dpy, ev.xkey.keycode, 0, 0);
                    if (ks >= 'a' && ks <= 'z') ks = ks - 'a' + 'A';
                    if (ks < 256) g_key[ks] = 0;
                    break;
                }
                case MotionNotify:
                    g_mx = ev.xmotion.x; g_my = ev.xmotion.y; break;
                case ButtonPress:
                    if (ev.xbutton.button == Button1) g_mb |= 1;
                    if (ev.xbutton.button == Button3) g_mb |= 2;
                    break;
                case ButtonRelease:
                    if (ev.xbutton.button == Button1) g_mb &= ~1;
                    if (ev.xbutton.button == Button3) g_mb &= ~2;
                    break;
                case ConfigureNotify:
                    g_w = ev.xconfigure.width; g_h = ev.xconfigure.height;
                    if (g_fb) { free(g_fb); g_fb = (unsigned char *)malloc((size_t)g_w * g_h * 4); memset(g_fb, 0, (size_t)g_w * g_h * 4); }
                    break;
                case ClientMessage:
                    g_open = 0; break;
                default: break;
                }
            }
            if (g_ximg) {
                g_ximg->data = (char *)g_fb;
                g_ximg->width = g_w;
                g_ximg->height = g_h;
                pfn_XPutImage(g_dpy, g_xwin, g_xgc, g_ximg, 0, 0, 0, 0, g_w, g_h);
                pfn_XFlush(g_dpy);
            }
            frames++;
            coma_sleep_ms(10);
        }
    }
#endif
}

/* ================================================================
   coma_ventana_cerrar
   ================================================================ */
void coma_ventana_cerrar(void) {
    if (!g_open) return;
#ifdef _WIN32
    if (g_use_vulkan) {
        if (pfn_vkDestroyFramebuffer && g_vk_fb) pfn_vkDestroyFramebuffer(g_vk_dev, g_vk_fb, NULL);
        if (pfn_vkDestroyImageView && g_vk_img_view) pfn_vkDestroyImageView(g_vk_dev, g_vk_img_view, NULL);
        if (pfn_vkDestroySwapchainKHR && g_vk_swap) pfn_vkDestroySwapchainKHR(g_vk_dev, g_vk_swap, NULL);
        if (pfn_vkDestroySurfaceKHR && g_vk_surf) pfn_vkDestroySurfaceKHR(g_vk_inst, g_vk_surf, NULL);
        if (pfn_vkDestroyDevice && g_vk_dev) pfn_vkDestroyDevice(g_vk_dev, NULL);
        if (pfn_vkDestroyInstance && g_vk_inst) pfn_vkDestroyInstance(g_vk_inst, NULL);
    }
    if (pReleaseDC && g_hdc && g_hwnd) { pReleaseDC(g_hwnd, g_hdc); g_hdc = NULL; }
    if (pDestroyWindow && g_hwnd) { pDestroyWindow(g_hwnd); g_hwnd = NULL; }
#else
    if (!g_use_vulkan) {
        if (pfn_XDestroyImage && g_ximg) { pfn_XDestroyImage(g_ximg); g_ximg = NULL; }
        if (pfn_XFreeGC && g_xgc && g_dpy) { pfn_XFreeGC(g_dpy, g_xgc); g_xgc = 0; }
        if (pfn_XDestroyWindow && g_xwin && g_dpy) { pfn_XDestroyWindow(g_dpy, g_xwin); g_xwin = 0; }
        if (pfn_XCloseDisplay && g_dpy) { pfn_XCloseDisplay(g_dpy); g_dpy = NULL; }
    }
#endif

    g_open = 0;
    if (g_fb) { free(g_fb); g_fb = NULL; }
}

/* ================================================================
   Impresión de decimales (plataforma-independiente)
   ================================================================ */
void coma_print_dbl0(double val) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%.0f", val);
    extern void coma_print_str(const char *);
    coma_print_str(buf);
}

void coma_print_dbl2(double val) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%.2f", val);
    extern void coma_print_str(const char *);
    coma_print_str(buf);
}

void coma_print_str(const char *s) {
    if (s) { printf("%s", s); fflush(stdout); }
}

void coma_ocultar_consola(void) {
#ifdef _WIN32
  extern void __stdcall FreeConsole(void);
  FreeConsole();
#endif
}


int coma_ventana_raton_x(void) { return g_mx; }
int coma_ventana_raton_y(void) { return g_my; }
int coma_ventana_boton_izq(void) { if (g_click_latch) { g_click_latch = 0; return 1; } return (g_mb & 1) ? 1 : 0; }
int coma_ventana_tecla(int vk) { return (vk >= 0 && vk < 256) ? g_key[vk] : 0; }


#include <string.h>
extern void coma_https_get(const char*, char**);
char* coma_https_get_str(const char* url) {
  char* out = NULL;
  coma_https_get(url, &out);
  if (!out) { out = (char*)malloc(1); if (out) out[0] = 0; }
  return out;
}

