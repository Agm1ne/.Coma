/* coma_x11.h — Declaraciones manuales de X11 (sin <X11/Xlib.h>)
   Para cross-compilación desde Windows a Linux. */

#ifndef COMA_X11_H
#define COMA_X11_H

#include <stdint.h>

/* Opaque types */
typedef struct _Display Display;
typedef unsigned long Window;
typedef unsigned long GC;
typedef struct _XImage {
    int width, height;
    char *data;
} XImage;
typedef unsigned long KeySym;
typedef unsigned long Atom;
typedef int Bool;

/* XEvent: union of all event types, sharing common header fields */
typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display* display;
    Window window;
    Window root;
    Window subwindow;
    long time;
    int x, y;
    int x_root, y_root;
    unsigned int state;
    unsigned int keycode;
    int same_screen;
} XKeyEvent;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display* display;
    Window window;
    Window root;
    Window subwindow;
    long time;
    int x, y;
    int x_root, y_root;
    unsigned int state;
    char is_hint;
    int same_screen;
} XMotionEvent;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display* display;
    Window event;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    int override_redirect;
} XConfigureEvent;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display* display;
    Window window;
    Atom message_type;
    int format;
    union { long l[5]; char b[20]; short s[10]; } data;
} XClientMessageEvent;

typedef union {
    int type;
    XKeyEvent xkey;
    XMotionEvent xmotion;
    XConfigureEvent xconfigure;
    XClientMessageEvent xclient;
    struct {
        int type;
        unsigned long serial;
        int send_event;
        Display* display;
        Window window;
        Window root;
        Window subwindow;
        long time;
        int x, y;
        int x_root, y_root;
        unsigned int state;
        unsigned int button;
        int same_screen;
    } xbutton;
} XEvent;

typedef struct {
    unsigned long background_pixel;
    unsigned long border_pixel;
    int bit_gravity;
    int win_gravity;
    int backing_store;
    unsigned long planemask;
    unsigned long border_pixel_unused;
    int override_redirect;
    int save_under;
    long event_mask;
    int do_not_propagate_mask;
} XSetWindowAttributes;

/* Constants */
#define ExposureMask       0x00000004
#define KeyPressMask       0x00000001
#define KeyReleaseMask     0x00000002
#define ButtonPressMask    0x00000004
#define ButtonReleaseMask  0x00000008
#define PointerMotionMask  0x00000040
#define StructureNotifyMask 0x00000800

#define KeyPress    2
#define KeyRelease  3
#define ButtonPress 4
#define ButtonRelease 5
#define MotionNotify 6
#define ConfigureNotify 22
#define ClientMessage 33

#define Button1 1
#define Button3 3

#define InputOutput 1
#define CopyFromParent 0
#define CWEventMask 0x00000001
#define ZPixmap 2

/* Function declarations */
Display* XOpenDisplay(const char* display_name);
Window XCreateWindow(Display* display, Window parent, int x, int y,
                     int width, int height, int border_width, int depth,
                     unsigned int class, void* visual,
                     unsigned long valuemask, XSetWindowAttributes* attributes);
int XStoreName(Display* display, Window window, const char* name);
int XMapWindow(Display* display, Window window);
int XFlush(Display* display);
int XPending(Display* display);
int XNextEvent(Display* display, XEvent* event_return);
int XCloseDisplay(Display* display);
int XDestroyImage(XImage* image);
int XFreeGC(Display* display, GC gc);
int XDestroyWindow(Display* display, Window window);
int XPutImage(Display* display, Window drawable, GC gc, XImage* image,
              int src_x, int src_y, int dest_x, int dest_y,
              int width, int height);
int DefaultScreen(Display* display);
Window RootWindow(Display* display, int screen_number);
GC XCreateGC(Display* display, Window drawable, unsigned long valuemask, void* values);
int XConnectionNumber(Display* display);
XImage* XCreateImage(Display* display, void* visual, unsigned int depth,
                     int format, int offset, char* data,
                     unsigned int width, unsigned int height,
                     int bitmap_pad, int bytes_per_line);
KeySym XkbKeycodeToKeysym(Display* display, unsigned int keycode, int group, int level);

#endif
