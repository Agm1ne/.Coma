/* Test de coma_str_assign con alloca no inicializado */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void coma_str_assign(char **dst, const char *src) {
    size_t n = src ? strlen(src) + 1 : 1;
    char *p = (char *)malloc(n ? n : 1);
    if (!p) exit(1);
    if (src) memcpy(p, src, n);
    else p[0] = 0;
    free(*dst);
    *dst = p;
}

int main() {
    char **ptr = (char**)malloc(sizeof(char*));  // no inicializado
    // no hacemos *ptr = NULL
    coma_str_assign(ptr, "hola");
    printf("%s\n", *ptr);
    free(*ptr);
    free(ptr);
    return 0;
}
