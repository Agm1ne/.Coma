/* rt_bmp.c — Cargador BMP propio 24/32bpp sin comprimir (portable Win/Unix).
   Lee los campos del encabezado campo a campo (sin #pragma pack) para ser
   portable en cualquier compilador C. */
#include "coma_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned short read_le16(FILE *f) {
    unsigned char b[2];
    if (fread(b, 1, 2, f) != 2) return 0;
    return (unsigned short)(b[0] | (b[1] << 8));
}
static unsigned int read_le32(FILE *f) {
    unsigned char b[4];
    if (fread(b, 1, 4, f) != 4) return 0;
    return (unsigned int)(b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24));
}

int coma_bmp_load(const char* path, unsigned char** outData, int* outW, int* outH) {
    if (!path || !outData || !outW || !outH) return 0;
    FILE* f = fopen(path, "rb");
    if (!f) { coma_finfo(path); return 0; }
    unsigned short bfType = read_le16(f);
    if (bfType != 0x4D42) { fclose(f); return 0; }
    read_le32(f); /* bfSize */
    read_le16(f); /* bfReserved1 */
    read_le16(f); /* bfReserved2 */
    unsigned int bfOffBits = read_le32(f);
    unsigned int biSize = read_le32(f);
    if (biSize < 40) { fclose(f); return 0; }
    int biWidth = (int)read_le32(f);
    int biHeight = (int)read_le32(f);
    read_le16(f); /* biPlanes */
    unsigned short biBitCount = read_le16(f);
    unsigned int biCompression = read_le32(f);
    if (biCompression != 0) { fclose(f); return 0; }
    if (biBitCount != 24 && biBitCount != 32) { fclose(f); return 0; }
    int w = biWidth;
    int h = biHeight;
    int topdown = 0;
    if (h < 0) { h = -h; topdown = 1; }
    int bpp = biBitCount / 8;
    int rowBytes = ((w * bpp + 3) / 4) * 4;
    unsigned char* pixels = (unsigned char*)malloc((size_t)w * h * 4);
    if (!pixels) { fclose(f); return 0; }
    fseek(f, (long)bfOffBits, SEEK_SET);
    for (int y = 0; y < h; y++) {
        unsigned char* row = pixels + (size_t)(topdown ? y : (h - 1 - y)) * w * 4;
        unsigned char* tmp = (unsigned char*)malloc((size_t)rowBytes);
        if (!tmp) { free(pixels); fclose(f); return 0; }
        if (fread(tmp, 1, (size_t)rowBytes, f) != (size_t)rowBytes) { free(tmp); free(pixels); fclose(f); return 0; }
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

/* Implementación de coma_finfo (plataforma-independiente) */
void coma_finfo(const char* path) {
    if (path) { printf("finfo: %s\n", path); fflush(stdout); }
}
