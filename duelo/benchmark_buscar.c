// duelo/benchmark_buscar.c — Búsqueda lineal en C para comparar
#include <stdio.h>
#include <time.h>

int buscar_c(int *lista, int n, int valor) {
    for (int i = 0; i < n; i++) {
        if (lista[i] == valor) return i + 1;
    }
    return 0;
}

int main() {
    int lista[] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    int n = 9;
    clock_t start = clock();
    int r1 = buscar_c(lista, n, 7);
    int r2 = buscar_c(lista, n, 99);
    clock_t end = clock();
    double secs = (double)(end - start) / CLOCKS_PER_SEC;
    printf("Buscar 7: %d\n", r1);
    printf("Buscar 99: %d\n", r2);
    printf("Tiempo C: %.6f segundos\n", secs);
    return 0;
}
