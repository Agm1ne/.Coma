/* rt_bmp.c — Cargador BMP propio 24/32bpp sin comprimir */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#pragma pack(push, 1)
typedef struct {
    unsigned short bfType;
    unsigned int bfSize;
    unsigned short bfReserved1;
    unsigned short bfReserved2;
    unsigned int bfOffBits;
} BITMAPFILEHEADER;

typedef struct {
    unsigned int biSize;
    int biWidth;
    int biHeight;
    unsigned short biPlanes;
    unsigned short biBitCount;
    unsigned int biCompression;
    unsigned int biSizeImage;
    int biXPelsPerMeter;
    int biYPelsPerMeter;
    unsigned int biClrUsed;
    unsigned int biClrImportant;
} BITMAPINFOHEADER;
#pragma pack(pop)

int coma_bmp_load(const char* path, unsigned char** outData, int* outW, int* outH) {
    if (!path || !outData || !outW || !outH) return 0;
    FILE* f = fopen(path, "rb");
    if (!f) { coma_finfo(path); return 0; }
    BITMAPFILEHEADER bfh;
    BITMAPINFOHEADER bih;
    if (fread(&bfh, sizeof(bfh), 1, f) != 1) { fclose(f); return 0; }
    if (bfh.bfType != 0x4D42) { fclose(f); return 0; }
    if (fread(&bih, sizeof(bih), 1, f) != 1) { fclose(f); return 0; }
    if (bih.biCompression != 0) { fclose(f); return 0; }
    if (bih.biBitCount != 24 && bih.biBitCount != 32) { fclose(f); return 0; }
    int w = bih.biWidth;
    int h = bih.biHeight;
    int topdown = 0;
    if (h < 0) { h = -h; topdown = 1; }
    int bpp = bih.biBitCount / 8;
    int rowBytes = ((w * bpp + 3) / 4) * 4;
    unsigned char* pixels = (unsigned char*)malloc((size_t)w * h * 4);
    if (!pixels) { fclose(f); return 0; }
    fseek(f, bfh.bfOffBits, SEEK_SET);
    for (int y = 0; y < h; y++) {
        unsigned char* row = pixels + (size_t)(topdown ? y : (h - 1 - y)) * w * 4;
        unsigned char* tmp = (unsigned char*)malloc(rowBytes);
        fread(tmp, 1, rowBytes, f);
        for (int x = 0; x < w; x++) {
            unsigned char b = tmp[x * bpp + 0];
            unsigned char g = tmp[x * bpp + 1];
            unsigned char r = tmp[x * bpp + 2];
            unsigned char a = bpp == 4 ? tmp[x * bpp + 3] : 255;
            row[x * 4 + 0] = r;
            row[x * 4 + 1] = g;
            row[x * 4 + 2] = b;
            row[x * 4 + 3] = a;
        }
        free(tmp);
    }
    fclose(f);
    *outData = pixels;
    *outW = w;
    *outH = h;
    return 1;
}

#else
#include <stdio.h>
#include <stdlib.h>
int coma_bmp_load(const char* path, unsigned char** outData, int* outW, int* outH) {
    (void)path; (void)outData; (void)outW; (void)outH;
    printf("E202 bmp: solo Windows");
    coma_einfo();
    printf("\n");
    exit(1);
    return 0;
}
#endif
