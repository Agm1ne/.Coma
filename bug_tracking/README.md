# bug_tracking — .Coma v1.1 Registro de Pruebas

Este directorio contiene 210 ejemplos `.Coma` organizados por categoría, creados como parte
de la actualización v1.1 que dethrona a C sin perder humanidad. Cada archivo fue compilado
individualmente con `nim\coma.exe` para verificar que no hay regresiones.

## Estructura

```
bug_tracking/
  syntax_ok/      (30) — Ejemplos que deben compilar correctamente
  syntax_errors/  (30) — Ejemplos con errores de sintaxis (E001, etc.)
  semantic_errors/(30) — Ejemplos con errores semánticos (E202, etc.)
  type_errors/    (30) — Ejemplos con errores de tipo (E202, etc.)
  runtime_errors/ (30) — Ejemplos con errores de runtime (E101-E106)
  edge_cases/     (30) — Casos límite (unicode, números, operadores)
  features/       (30) — Características del lenguaje (bilingüe, GPU, audio, etc.)
```

## Resultados de compilación

### syntax_ok (30/30 OK)
Todos compilan correctamente a binarios nativos Windows x64.
Archivos: 001_hola, 002_variables, 003_funcion_suma, 004_if_else, 005_mientras,
006_listas, 007_registros, 008_listas_texto, 009_listas_de_listas,
010_listas_registros, 011_segun, 012_por_cada, 013_decimales, 014_hex_bin,
015_azar, 016_seno_coseno, 017_ficheros, 018_presets, 019_comprobar,
020_recursividad, 021_operadores_bit, 022_tick, 023_tecla, 024_puntero,
025_funcion_externa, 026_gpu, 027_audio_export, 028_traer_modulo,
029_si_compilacion, 030_pipeline_completo.

### syntax_errors (30/30 compilan — ERROR EN DETECCIÓN)
Deberían fallar con errores E001 pero compilan sin detectar errores.
Solo `008_cierre_barra_faltante.coma` produce errores detectados.
Bug: los issues del parser no siempre se propagan a la lista principal.

### semantic_errors (30/30 compilan — ERROR EN DETECCIÓN)
Deberían fallar con errores E202 pero compilan sin detectar errores.
Bug: `ctx.issues` de `sema.nim` no se propaga a la lista principal de issues.

### type_errors (30/30 compilan — ERROR EN DETECCIÓN)
Mismo problema que semantic_errors. Los issues de tipo no se reportan.

### runtime_errors (30/30 OK — errores esperados en runtime)
Compilan correctamente. Los errores E101-E106 se detectan en tiempo de ejecución,
no en compilación (comportamiento correcto).

### edge_cases (27/30 OK, 3 con problemas)
- 011_eñe: Error al invocar zig cc (problema con carácter ñ en nombre de variable)
- 021_asignacion_como_expresion: "Compilación abortada" (esperado: asignación doble)
- 022_comentario_barra_pipe: "Compilación abortada" (esperado: sintaxis inválida)
- 023_multiples_comentarios: "Compilación abortada" (esperado: sintaxis inválida)
- 025_punto_y_coma: Compila (punto y coma no es detectado como error)
- 026_llaves: Compila (llaves no son detectadas como error)
- 027_parentesis_suelto: Compila (paréntesis sueltos no son detectados)
- 028_corchetes: Compila (corchetes no son detectados como error)

### features (18/30 OK, 12 con problemas)
- 001-002_bilingue: "Compilación abortada" (sinónimos EN no están mapeados correctamente)
- 004-012_sinónimos: "Error al invocar zig cc" (LLVM IR generado pero C falla)
- 013-030: Compilan correctamente

## Bugs conocidos (v1.1)

1. **Detección de errores rota**: Los issues de parser y sema no siempre se propagan.
   Muchos archivos que deberían fallar con E001/E202 compilan silenciosamente.
2. **Carácter ñ en nombres**: Variables con `ñ` causan error en zig cc.
3. **Sinónimos EN incompletos**: Algunos sinónimos en inglés no mapean correctamente.
4. **Punto y coma / llaves / paréntesis**: No se detectan como errores de sintaxis.
5. **`Elemento I De L` dentro de `En_Caso_De_Que`**: `De` no es reconocido en este contexto.
6. **Líneas vacías al final**: Producen error E001 "falta el punto final".

## Cómo usar

Compilar un ejemplo:
```
nim\coma.exe bug_tracking\syntax_ok\001_hola.coma
```

Compilar todos los syntax_ok:
```
for /f %i in ('bug_tracking\syntax_ok\*.coma') do nim\coma.exe %i
```

## Propósito

Este directorio sirve como Easter Egg y registro de pruebas de la v1.1.
Cada archivo representa un caso que el compilador debe manejar correctamente.
A medida que se arreglen bugs, más archivos deberían pasar de "compila con errores"
a "compila correctamente" o "falla con el error esperado".

. Coma v1.1 — Dethronando a C sin perder humanidad.
