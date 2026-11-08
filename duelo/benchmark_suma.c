// duelo/benchmark_suma.c — Suma 1..N en C para comparar
#include <stdio.h>
#include <time.h>

long long suma_c(int n) {
    long long total = 0;
    for (int i = 1; i <= n; i++) {
        total += i;
    }
    return total;
}

int main() {
    clock_t start = clock();
    long long r = suma_c(1000000);
    clock_t end = clock();
    double secs = (double)(end - start) / CLOCKS_PER_SEC;
    printf("Suma 1..1000000 en C: %lld\n", r);
    printf("Tiempo C: %.6f segundos\n", secs);
    return 0;
}
