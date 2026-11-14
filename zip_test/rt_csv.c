/* rt_csv.c — CSV parser simple para .Coma */
#include "coma_rt.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static char g_csv_err[256] = "";
static int g_csv_rows = 0;
static int g_csv_cols = 0;
static char ***g_csv_data = NULL;

static char *csv_next_field(const char **p) {
    if (**p == '"') {
        (*p)++;
        int cap = 64, len = 0;
        char *s = (char *)malloc(cap);
        if (!s) return NULL;
        while (**p && **p != '"') {
            if (**p == '"' && (*p)[1] == '"') {
                if (len + 1 >= cap) { cap *= 2; s = (char *)realloc(s, cap); if (!s) return NULL; }
                s[len++] = '"';
                (*p) += 2;
            } else {
                if (len + 1 >= cap) { cap *= 2; s = (char *)realloc(s, cap); if (!s) return NULL; }
                s[len++] = **p;
                (*p)++;
            }
        }
        if (**p == '"') (*p)++;
        s[len] = '\0';
        return s;
    } else {
        int cap = 64, len = 0;
        char *s = (char *)malloc(cap);
        if (!s) return NULL;
        while (**p && **p != ',' && **p != '\n' && **p != '\r') {
            if (len + 1 >= cap) { cap *= 2; s = (char *)realloc(s, cap); if (!s) return NULL; }
            s[len++] = **p;
            (*p)++;
        }
        s[len] = '\0';
        return s;
    }
}

int coma_csv_parse(const char *text) {
    if (g_csv_data) {
        for (int i = 0; i < g_csv_rows; i++) {
            for (int j = 0; j < g_csv_cols; j++) free(g_csv_data[i][j]);
            free(g_csv_data[i]);
        }
        free(g_csv_data);
        g_csv_data = NULL;
    }
    g_csv_rows = 0;
    g_csv_cols = 0;
    
    const char *p = text;
    int cap_rows = 16, cap_cols = 16;
    g_csv_data = (char ***)malloc(cap_rows * sizeof(char **));
    if (!g_csv_data) return -1;
    
    while (*p) {
        if (g_csv_rows >= cap_rows) { cap_rows *= 2; g_csv_data = (char ***)realloc(g_csv_data, cap_rows * sizeof(char **)); if (!g_csv_data) return -1; }
        g_csv_data[g_csv_rows] = (char **)malloc(cap_cols * sizeof(char *));
        if (!g_csv_data[g_csv_rows]) return -1;
        int cols = 0;
        while (*p && *p != '\n') {
            if (cols >= cap_cols) { cap_cols *= 2; g_csv_data[g_csv_rows] = (char **)realloc(g_csv_data[g_csv_rows], cap_cols * sizeof(char *)); if (!g_csv_data[g_csv_rows]) return -1; }
            char *field = csv_next_field(&p);
            if (!field) break;
            g_csv_data[g_csv_rows][cols++] = field;
            if (*p == ',') p++;
        }
        if (*p == '\n') p++;
        else if (*p == '\r') { p++; if (*p == '\n') p++; }
        g_csv_cols = cols;
        g_csv_rows++;
    }
    return g_csv_rows;
}

int coma_csv_rows(void) { return g_csv_rows; }
int coma_csv_cols(void) { return g_csv_cols; }
const char *coma_csv_cell(int row, int col) {
    if (!g_csv_data || row < 0 || row >= g_csv_rows || col < 0 || col >= g_csv_cols) return "";
    return g_csv_data[row][col];
}
const char *coma_csv_err(void) { return g_csv_err; }

void coma_csv_parse_file(const char *filePath) { FILE *f = fopen(filePath, "rb"); if (!f) { snprintf(g_csv_err, sizeof(g_csv_err), "no se puede abrir %s", filePath); return; } fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET); char *buf = (char*)malloc(sz+1); if (!buf) { fclose(f); return; } fread(buf, 1, sz, f); buf[sz] = 0; fclose(f); coma_csv_parse(buf); free(buf); }

