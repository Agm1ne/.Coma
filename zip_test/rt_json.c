/* rt_json.c — parser y serializador JSON para .Coma */
#include "coma_rt.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

/* Tipos JSON internos */
#define JSON_NULL   0
#define JSON_BOOL   1
#define JSON_INT    2
#define JSON_DOUBLE 3
#define JSON_STR    4
#define JSON_ARRAY  5
#define JSON_OBJECT 6

typedef struct jval_t {
    int type;
    int ival;
    double dval;
    char *sval;
    int bval;
    struct jval_t **items;
    int nitems;
    char **keys;
} jval_t;

static const char *g_json = NULL;
static int g_json_pos = 0;

static void skip_ws(void) {
    while (g_json[g_json_pos] && isspace((unsigned char)g_json[g_json_pos]))
        g_json_pos++;
}

static char peek(void) {
    skip_ws();
    return g_json[g_json_pos];
}

static char nextc(void) {
    skip_ws();
    return g_json[g_json_pos++];
}

static jval_t *parse_value(void);

static char *parse_string(void) {
    nextc(); /* consume opening quote */
    int cap = 64, len = 0;
    char *s = (char *)malloc(cap);
    if (!s) return NULL;
    while (g_json[g_json_pos] && g_json[g_json_pos] != '"') {
        char c = g_json[g_json_pos++];
        if (c == '\\') {
            c = g_json[g_json_pos++];
            switch (c) {
                case '"': c = '"'; break;
                case '\\': c = '\\'; break;
                case '/': c = '/'; break;
                case 'b': c = '\b'; break;
                case 'f': c = '\f'; break;
                case 'n': c = '\n'; break;
                case 'r': c = '\r'; break;
                case 't': c = '\t'; break;
                default: break;
            }
        }
        if (len + 1 >= cap) {
            cap *= 2;
            s = (char *)realloc(s, cap);
            if (!s) return NULL;
        }
        s[len++] = c;
    }
    if (g_json[g_json_pos] == '"') g_json_pos++;
    s[len] = '\0';
    return s;
}

static jval_t *parse_value(void) {
    skip_ws();
    char c = peek();
    jval_t *v = (jval_t *)calloc(1, sizeof(jval_t));
    if (!v) return NULL;

    if (c == '"') {
        v->type = JSON_STR;
        v->sval = parse_string();
    } else if (c == 't' || c == 'f') {
        v->type = JSON_BOOL;
        if (g_json[g_json_pos] == 't') {
            v->bval = 1;
            g_json_pos += 4; /* "true" */
        } else {
            v->bval = 0;
            g_json_pos += 5; /* "false" */
        }
    } else if (c == 'n') {
        v->type = JSON_NULL;
        g_json_pos += 4; /* "null" */
    } else if (c == '[') {
        v->type = JSON_ARRAY;
        nextc(); /* consume '[' */
        if (peek() == ']') { nextc(); return v; }
        int cap = 8, n = 0;
        v->items = (jval_t **)calloc(cap, sizeof(jval_t *));
        while (peek() != ']' && g_json[g_json_pos]) {
            jval_t *item = parse_value();
            if (!item) break;
            if (n >= cap) {
                cap *= 2;
                v->items = (jval_t **)realloc(v->items, cap * sizeof(jval_t *));
            }
            v->items[n++] = item;
            skip_ws();
            if (peek() == ',') nextc();
        }
        if (peek() == ']') nextc();
        v->nitems = n;
    } else if (c == '{') {
        v->type = JSON_OBJECT;
        nextc(); /* consume '{' */
        if (peek() == '}') { nextc(); return v; }
        int cap = 8, n = 0;
        v->items = (jval_t **)calloc(cap, sizeof(jval_t *));
        v->keys = (char **)calloc(cap, sizeof(char *));
        while (peek() != '}' && g_json[g_json_pos]) {
            skip_ws();
            if (peek() != '"') break;
            char *key = parse_string();
            skip_ws();
            if (peek() != ':') { free(key); break; }
            nextc(); /* consume ':' */
            jval_t *val = parse_value();
            if (!val) { free(key); break; }
            if (n >= cap) {
                cap *= 2;
                v->items = (jval_t **)realloc(v->items, cap * sizeof(jval_t *));
                v->keys = (char **)realloc(v->keys, cap * sizeof(char *));
            }
            v->items[n] = val;
            v->keys[n] = key;
            n++;
            skip_ws();
            if (peek() == ',') nextc();
        }
        if (peek() == '}') nextc();
        v->nitems = n;
        v->keys = v->keys; /* keep */
    } else {
        /* number */
        int start = g_json_pos;
        int is_double = 0;
        if (g_json[g_json_pos] == '-') g_json_pos++;
        while (isdigit((unsigned char)g_json[g_json_pos])) g_json_pos++;
        if (g_json[g_json_pos] == '.') {
            is_double = 1;
            g_json_pos++;
            while (isdigit((unsigned char)g_json[g_json_pos])) g_json_pos++;
        }
        if (g_json[g_json_pos] == 'e' || g_json[g_json_pos] == 'E') {
            is_double = 1;
            g_json_pos++;
            if (g_json[g_json_pos] == '+' || g_json[g_json_pos] == '-') g_json_pos++;
            while (isdigit((unsigned char)g_json[g_json_pos])) g_json_pos++;
        }
        int len = g_json_pos - start;
        char *num = (char *)malloc(len + 1);
        if (!num) { free(v); return NULL; }
        memcpy(num, g_json + start, len);
        num[len] = '\0';
        if (is_double) {
            v->type = JSON_DOUBLE;
            v->dval = atof(num);
        } else {
            v->type = JSON_INT;
            v->ival = atoi(num);
        }
        free(num);
    }
    return v;
}

/* Parsed JSON result exposed to COMA */
static jval_t *g_json_root = NULL;
static char g_json_err[256] = "";

/* Parse JSON from a COMA global variable's string content */
void coma_json_parse_from_var(const char *srcVarName, const char *dstVarName) {
    /* In the LLVM IR, global variables are accessed directly.
       We look up the variable by name in a simple registry.
       For now, this is a placeholder: the actual variable content
       is passed via a global string pointer set by the frontend.
    */
    (void)srcVarName;
    (void)dstVarName;
    /* The frontend should have set g_json_text before calling this */
}

static const char *g_json_text = NULL;

void coma_json_set_text(const char *text) {
    g_json_text = text;
}

/* Parse JSON from a file path. dstVarName is the COMA variable that gets the result handle. */
void coma_json_parse_file(const char *filePath, const char *dstVarName) {
    (void)dstVarName;
    FILE *f = fopen(filePath, "r");
    if (!f) {
        snprintf(g_json_err, sizeof(g_json_err), "no se puede abrir archivo JSON: %s", filePath);
        g_json_root = NULL;
        return;
    }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) {
        fclose(f);
        snprintf(g_json_err, sizeof(g_json_err), "archivo JSON vacio: %s", filePath);
        g_json_root = NULL;
        return;
    }
    char *text = (char *)malloc(len + 1);
    if (!text) {
        fclose(f);
        g_json_root = NULL;
        return;
    }
    fread(text, 1, len, f);
    text[len] = '\0';
    fclose(f);
    g_json = text;
    g_json_pos = 0;
    g_json_err[0] = '\0';
    g_json_root = parse_value();
    free(text);
    if (!g_json_root) {
        snprintf(g_json_err, sizeof(g_json_err), "JSON parse error en %s", filePath);
    }
}

/* Liberar el JSON parseado */
void coma_json_free(void) {
    if (g_json_root) {
        /* simple: don't free for now */
        g_json_root = NULL;
    }
}

int coma_json_parse(const char *text) {
    if (g_json_root) {
        /* free previous */
        /* (simple leak for now, acceptable for v1) */
    }
    g_json = text;
    g_json_pos = 0;
    g_json_err[0] = '\0';
    g_json_root = parse_value();
    if (!g_json_root) {
        snprintf(g_json_err, sizeof(g_json_err), "JSON parse error at pos %d", g_json_pos);
        return -1;
    }
    return 0;
}

int coma_json_get_int(const char *key) {
    if (!g_json_root || g_json_root->type != JSON_OBJECT) return 0;
    for (int i = 0; i < g_json_root->nitems; i++) {
        if (g_json_root->keys[i] && strcmp(g_json_root->keys[i], key) == 0) {
            jval_t *v = g_json_root->items[i];
            if (v->type == JSON_INT) return v->ival;
            if (v->type == JSON_DOUBLE) return (int)v->dval;
            if (v->type == JSON_BOOL) return v->bval ? 1 : 0;
        }
    }
    return 0;
}

double coma_json_get_double(const char *key) {
    if (!g_json_root || g_json_root->type != JSON_OBJECT) return 0.0;
    for (int i = 0; i < g_json_root->nitems; i++) {
        if (g_json_root->keys[i] && strcmp(g_json_root->keys[i], key) == 0) {
            jval_t *v = g_json_root->items[i];
            if (v->type == JSON_DOUBLE) return v->dval;
            if (v->type == JSON_INT) return (double)v->ival;
            if (v->type == JSON_BOOL) return v->bval ? 1.0 : 0.0;
        }
    }
    return 0.0;
}

const char *coma_json_get_str(const char *key) {
    if (!g_json_root || g_json_root->type != JSON_OBJECT) return "";
    for (int i = 0; i < g_json_root->nitems; i++) {
        if (g_json_root->keys[i] && strcmp(g_json_root->keys[i], key) == 0) {
            jval_t *v = g_json_root->items[i];
            if (v->type == JSON_STR) return v->sval;
        }
    }
    return "";
}

int coma_json_get_bool(const char *key) {
    if (!g_json_root || g_json_root->type != JSON_OBJECT) return 0;
    for (int i = 0; i < g_json_root->nitems; i++) {
        if (g_json_root->keys[i] && strcmp(g_json_root->keys[i], key) == 0) {
            jval_t *v = g_json_root->items[i];
            if (v->type == JSON_BOOL) return v->bval;
            if (v->type == JSON_INT) return v->ival != 0;
            if (v->type == JSON_DOUBLE) return v->dval != 0.0;
        }
    }
    return 0;
}

int coma_json_array_len(void) {
    if (!g_json_root || g_json_root->type != JSON_ARRAY) return 0;
    return g_json_root->nitems;
}

int coma_json_array_get_int(int idx) {
    if (!g_json_root || g_json_root->type != JSON_ARRAY) return 0;
    if (idx < 0 || idx >= g_json_root->nitems) return 0;
    jval_t *v = g_json_root->items[idx];
    if (v->type == JSON_INT) return v->ival;
    if (v->type == JSON_DOUBLE) return (int)v->dval;
    if (v->type == JSON_BOOL) return v->bval ? 1 : 0;
    return 0;
}

const char *coma_json_array_get_str(int idx) {
    if (!g_json_root || g_json_root->type != JSON_ARRAY) return "";
    if (idx < 0 || idx >= g_json_root->nitems) return "";
    jval_t *v = g_json_root->items[idx];
    if (v->type == JSON_STR) return v->sval;
    return "";
}

const char *coma_json_err(void) {
    return g_json_err;
}

/* Simple serializer: takes key/value pairs and produces JSON text */
static char *escape_json(const char *s) {
    int cap = 64, len = 0;
    char *out = (char *)malloc(cap);
    if (!out) return NULL;
    for (int i = 0; s[i]; i++) {
        char c = s[i];
        char esc[8] = "";
        int elen = 0;
        switch (c) {
            case '"':  esc[0] = '\\'; esc[1] = '"'; elen = 2; break;
            case '\\': esc[0] = '\\'; esc[1] = '\\'; elen = 2; break;
            case '\n': esc[0] = '\\'; esc[1] = 'n'; elen = 2; break;
            case '\r': esc[0] = '\\'; esc[1] = 'r'; elen = 2; break;
            case '\t': esc[0] = '\\'; esc[1] = 't'; elen = 2; break;
            default:   esc[0] = c; elen = 1; break;
        }
        if (len + elen + 1 >= cap) {
            cap *= 2;
            out = (char *)realloc(out, cap);
            if (!out) return NULL;
        }
        memcpy(out + len, esc, elen);
        len += elen;
    }
    out[len] = '\0';
    return out;
}

/* coma_json_serialize: recibe texto plano con formato "clave:valor;clave2:valor2"
   y devuelve un JSON objeto. */
char *coma_json_serialize_kv(const char *kvtext) {
    int cap = 256, len = 0;
    char *out = (char *)malloc(cap);
    if (!out) return NULL;
    len = snprintf(out, cap, "{");
    const char *p = kvtext;
    int first = 1;
    while (*p) {
        /* parse key */
        int klen = 0;
        while (*p && *p != ':' && *p != ';') { p++; klen++; }
        if (klen == 0) break;
        char *key = (char *)malloc(klen + 1);
        if (!key) break;
        memcpy(key, p - klen, klen);
        key[klen] = '\0';
        if (*p == ':') p++;
        /* parse value */
        int vlen = 0;
        while (*p && *p != ';') { p++; vlen++; }
        char *val = (char *)malloc(vlen + 1);
        if (!val) { free(key); break; }
        memcpy(val, p - vlen, vlen);
        val[vlen] = '\0';
        if (*p == ';') p++;
        char *ekey = escape_json(key);
        char *eval = escape_json(val);
        int need = snprintf(NULL, 0, "%s\"%s\":\"%s\"", first ? "" : ",", ekey, eval);
        if (len + need + 1 >= cap) {
            cap = (len + need + 1) * 2;
            out = (char *)realloc(out, cap);
            if (!out) { free(ekey); free(eval); free(key); free(val); break; }
        }
        len += snprintf(out + len, cap - len, "%s\"%s\":\"%s\"", first ? "" : ",", ekey, eval);
        first = 0;
        free(ekey); free(eval); free(key); free(val);
    }
    if (len + 2 >= cap) {
        cap = len + 2;
        out = (char *)realloc(out, cap);
    }
    snprintf(out + len, cap - len, "}");
    return out;
}
