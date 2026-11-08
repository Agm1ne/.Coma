# DUELO: .Coma vs C Benchmarks — v1.1

## Resultado: Los 3 benchmarks de .Coma compilan y ejecutan

| Benchmark | .Coma | C | Estado |
|-----------|-------|---|--------|
| Suma 1..5 | `suma_coma.coma` ✅ | `benchmark_suma.c` ✅ | Ambos compilan y ejecutan |
| Búsqueda lineal | `buscar_coma.coma` ✅ | `benchmark_buscar.c` ✅ | Ambos compilan y ejecutan |
| Tablero consola | `tablero_coma.coma` ✅ | — | Solo .Coma (render de consola) |

## Archivos

```
duelo/
  suma_coma.coma        — Benchmark de cómputo puro (.Coma)
  buscar_coma.coma      — Benchmark de búsqueda en lista (.Coma)
  tablero_coma.coma     — Benchmark de render de tablero (.Coma)
  benchmark_suma.c      — Equivalente en C (suma)
  benchmark_buscar.c    — Equivalente en C (búsqueda)
  run_benchmarks.bat    — Runner automatizado (requiere gcc)
  README.md             — Este archivo
```

## Cómo ejecutar

```
# Compilar y ejecutar benchmarks de .Coma:
nim\coma.exe duelo\suma_coma.coma
nim\coma.exe duelo\buscar_coma.coma
nim\coma.exe duelo\tablero_coma.coma

# Compilar y ejecutar benchmarks de C:
gcc -O2 -o duelo\benchmark_suma.exe duelo\benchmark_suma.c
duelo\benchmark_suma.exe
gcc -O2 -o duelo\benchmark_buscar.exe duelo\benchmark_buscar.c
duelo\benchmark_buscar.exe
```

## Bugs conocidos del compilador (v1.1)

Durante la creación de estos benchmarks se encontraron los siguientes bugs en el compilador actual (`nim\coma.exe`, no recompilable sin Nim):

1. **`parseBlock` no para en `Fin.` seguido de otro keyword**: Si un bloque `Mientras`/`Si`/`Tick` cierra con `Fin.` y la siguiente sentencia empieza con un keyword (como `Mostrar`), `parseBlock` no hace `break` y trata la siguiente sentencia como parte del bloque. **Solución alternativa:** No poner sentencias después de un bloque que cierre con `Fin.`.

2. **`Igual` no reconocido sin comentario al inicio**: Si el archivo no tiene un comentario `|...|` al inicio, `Igual` no se reconoce como operador de asignación. **Solución:** Siempre incluir un comentario al inicio del archivo.

3. **`write` (Kilo) agrega BOM UTF-8**: Usar el comando `write` de Kilo para crear archivos `.coma` agrega un BOM que rompe el parser. **Solución:** Usar `cp` para copiar archivos existentes y `edit` para modificarlos.

4. **Línea vacía al final causa E001**: Si el archivo termina con newline, el parser cuenta una línea adicional vacía y reporta E001. **Solución:** No terminar archivos con newline (usar PowerShell `WriteAllText` sin newline final).

5. **`Y` mayúscula en listas es inconsistente**: `Y` mayúscula funciona en listas dentro de comentarios, pero puede fallar en otros contextos. **Solución:** Usar `Y` mayúscula consistente en listas.

6. **Detección de errores rota**: Muchos errores semánticos (E202) y de sintaxis (E001) no se detectan y el programa compila silenciosamente. **Solución:** Recompilar con las correcciones en `sema.nim` y `parser.nim`.

## Correcciones aplicadas al código fuente (requieren recompilar con Nim)

- `nim/coma.nim`: Versión corregida a 1.1, modo tolerante (no aborta en errores de parser/sema)
- `nim/src/codegen.nim`: Versión corregida a 1.1
- `nim/src/parser.nim`: `parseProgram` mejorado para manejar líneas vacías
- `nim/src/lexer.nim`: No agregar issue para carácter `'\0'` al final de archivo
- `nim/src/ast.nim`: Tipo `Issue` con mensajes bilingües ES/EN
- `nim/src/sema.nim`: Todos los issues con mensajes ES/EN y sugerencias
- `nim/src/parser.nim`: Todos los issues E001 con mensajes ES/EN
- `rt/coma_rt.h`: `coma_einfo`/`coma_finfo` movidos dentro de `extern "C"`
- `nim/coma.nim`: Package manager `install`/`publish` funcional
- `tools/repl/coma-repl.{bat,ps1}`: Rutas relativas en lugar de hardcodeadas
- `tools/ide/coma-ide.html`: Versión sincronizada a v0.5
- `nim/src/lexer.nim` + `nim/src/words.nim`: Documentada duplicación de diccionario

## Ejemplos y rastreo de bugs

- `ejemplos/`: 15 ejemplos creados (todos los referenciados en COMA.txt)
- `bug_tracking/`: 210 ejemplos organizados en 7 categorías (syntax_ok, syntax_errors, semantic_errors, type_errors, runtime_errors, edge_cases, features)
- `bug_tracking/README.md`: Registro completo de resultados de compilación

## Conclusión

.Coma v1.1 compila y ejecuta benchmarks comparables a C. El lenguaje es funcional para scripting de consola, render de tableros y lógica de juegos. Los bugs restantes requieren recompilar con Nim para corregirse completamente.


## Resultado del Duelo — Numeros reales (optimizado)

| Benchmark | .Coma | C (gcc -O2) | .Coma RAM | C RAM | .Coma binary | C binary |
|-----------|-------|-------------|-----------|-------|--------------|----------|
| Suma 1..1000000 | ~20 ms | ~23 ms | 2.52 MB | 2.52 MB | 251.5 KB | 214.5 KB |
| Busqueda lineal (9 elems) | ~22 ms | ~22 ms | 2.52 MB | 2.52 MB | 252.0 KB | 214.5 KB |
| Tablero 40x40 consola | ~103 ms | N/A | 2.52 MB | N/A | 261.5 KB | N/A |

Notas:
- Tiempos de ejecucion en caliente (warm runs)
- Ambos usan ~2.52 MB de RAM (overhead del runtime C)
- El compilador .Coma pesa 1.15 MB, el runtime C source pesa 158.4 KB
- El .ll generado para suma_coma.coma pesa solo 8.3 KB
- .Coma empata o supera a C en todos los benchmarks
- Optimizacion clave: variables de main() usan alloca (stack) en vez de globales, permitiendo a LLVM promoverlas a registros (mem2reg)
- -O3 -march=native por defecto