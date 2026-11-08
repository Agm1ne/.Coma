# Batería de tests de .Coma

## Estado
- **58 tests reales**: 15 `ok_*` (compilan, ejecutan, comparan salida con `.txt`), 40 `mal_*_ECCC` (NO compilan y el mensaje debe contener el código `ECCC` del nombre), 3 `run_*` (compilan, deben fallar en ejecución con exit code 1 y salida igual a `.txt`).
- `casos\falsa.coma` es un **fixture/módulo helper** usado por `ok_traer_ext.coma` (no es un caso autónomo).
- El runner es `correr.bat` (Windows). Limpia `*.exe`, `*.ll`, `*.sal`, `*.tmp`, `*.pdb`, `*.obj`.

## Golden master
- `baseline.txt` = salida completa de la última ejecución válida.
- **Gate Fase 0**: sin baseline verde, no se pasa a Fase 1.

## ¿Qué cubre?
| Categoría | Casos | Notas |
|---|---|---|
| Flujo/funciones/básicos | `ok_flujo`, `ok_funcion`, `ok_hola`, `ok_anidadas` | Sintaxis, llamadas, anidamiento |
| Listas/registros | `ok_listas`, `ok_asa`, `ok_recursiva` | Listas, asas, recursión |
| Ficheros/FFI | `ok_fichero`, `ok_ffi`, `ok_traer_ext` | Ficheros, `cargar`/`funcion externa`, `traer` |
| Errores runtime | `run_e101`, `run_e102`, `run_e105` | Índice fuera, división por cero, fichero |
| GPU/HTTPS | `ok_gpu`, `mal_gpu_*`, `mal_https_*` | **Parcial**: `ok_gpu.coma` filtra la salida `gpu:` para comparar. No hay test que valide cálculo GPU real. |
| Memoria/texto | `ok_mem`, `ok_texto_doble` | Strings dinámicos |
| Errores estáticos | `mal_*_E001/E003/E202` | Léxico, sintaxis, semántica, tipos |

## ¿Qué NO cubre?
- **Ventana 2D/píxeles**: nada aún (se añade en Fase 4).
- **Servicios/administrador**: nada aún (se añade en Fase 3).
- **HTTPS real**: solo errores estáticos (`mal_https_*`), sin petición HTTP de verdad.
- **GPU real**: `ok_gpu` filtra `gpu:`; no verifica resultado numérico de compute.
- **TCP red real**: sin test de conexión real.
- **Mando/Guitarra**: sin tests automáticos (requiere hardware).
- **Punteros**: poca cobertura explícita.
- **Módulos cruzados complejos**: cubierto parcialmente por `ok_traer_ext`.
- **Rendimiento**: los benchmarks viven en `duelo/` (se restauran en Fase 5).

## Notas
- Los `.pdb` y `.obj` ya **no** se dejan sucios: el runner los borra ahora.
- Al compilar con `zig cc` vía el driver, pueden aparecer artefactos en el caché de zig (`tools/toolchain/zig-cache/`).
