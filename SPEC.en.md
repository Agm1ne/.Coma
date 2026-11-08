# .Coma Specification (English Mirror)

> This is a mirror of [COMA.txt](COMA.txt). The Spanish original is normative; if they differ, `COMA.txt` wins.

**Version:** 1.1  
**Toolchain:** Nim 2.2.12 + zig 0.17.0  
**Bilingual:** Spanish/English with lexer normalization

## 1. Names
- Identifiers: letters, numbers, underscore. Variables MUST start with uppercase: `Vida`, `Heroe`, `Turno`.
- Keywords are lowercase canonical forms after normalization.
- Some uppercase commands remain for compatibility (`Mostrar`, `Funcion`, `Tecla`).
- All bilingual/colloquial aliases collapse to canonical forms in the lexer.

## 2. Terminator
- Every statement ends with `.` (except block closers like `fin.`).
- Blocks open with `si`, `en_caso_de_que`, `mientras`, `por_cada`, `funcion`, `tick` and close with `fin.` 
- Indentation is not required.

## 3. Numbers
- Integers: `5`, `25000`
- Decimals with comma: `3,14`
- Hex: `0xFF`, `0xCAFE_BABE`, `-0x10` with underscores
- Negatives: unary `menos`

## 4. Comments
- Vertical bar `| ...` ignores rest of line

## 5. Strings
- Double quotes `"Hola"`, UTF-8

## 6. Variables and assignment
- `Nombre igual Valor.`
- `igual` writes THROUGH aliases (never re-points). Reading reads the target.
- Implicit typing on first write; mixing types = E202
- `direccion de Var` returns pointer/handle for FFI/callbacks

## 7. Operators
- Arithmetic: `mas`, `menos`, `por`, `entre` (division by zero not folded, caught as E102 at runtime)
- Comparison: `es_igual_a`/`igual`, `es_distinto_de`, `es_mayor_que`, `es_menor_que`, `es_mayor_o_igual`, `es_menor_o_igual`, `es_equivalente_a` (case-insensitive)
- Logic: `y`, `o`, `no`
- Bitwise: `y_bit`, `o_bit`, `xor`, `desplaza_izquierda`, `desplaza_derecha`
- Unary `menos`, `no`

## 8. Show/Input
- `mostrar X.` prints line
- `pisa X.` same line
- `pedir Var.` reads line
- `comprobar "desc". ... fin.` for tests

## 9. Control flow
- `si Condicion.` ... `sino.` ... `fin.`
- `en_caso_de_que Condicion.` ... `fin.`
- `mientras Condicion.` ... `fin.` with `para.`, `sigue.`
- `por_cada E en Lista.` ... `fin.` with optional label `como Nombre`

## 10. Functions
- `funcion Nombre Param1 y Param2.` ... `devolver Valor.` ... `fin.`
- Calls: `Nombre A y B.`
- Recursion supported. Globals outside functions.

## 11. Lists
- `Lista igual lista 1 y 2 y 3.`
- Access: `Elemento 1 de Lista`, `Primero de Lista`, `Ultimo de Lista`
- Ops: `Agregar X a Lista.`, `Quitar X de Lista.`, `Quitar Primero de Lista.`, `Longitud de Lista`
- Lists of strings, nested lists, lists of records

## 12. Records
- `Heroe igual registro Vida 30 y Ataque 5.`
- Access: `Vida de Heroe`, `Heroe Vida`
- In `por_cada` over record lists use `Vida de E`
- Limited: currently globals per field; passing as args/return and text fields in record lists pending

## 13. Types
Implicit inference. Types: integer, decimal, text, boolean, list, list of text, list of lists, list of records, record, handle, pointer.

## 14. Errors
Human errors with line/column/code (E001,E002,E003,E005,E101,E102,E103,E104,E105,E106,E202), message + suggestion with edit distance. `coma_donde` prints line+function.

## 15. Bilingual/colloquial
Closed dictionary of ~500 ES/EN aliases normalized to canon in lexer. Compound phrases with longest-match tie-break (first declared wins). Short audited position table.

## 16. Modules and FFI
- `traer Modulo.` imports `coma/lib/modulo.coma` (declarations only)
- `cargar "user32.dll".` links library
- `funcion externa Beep Frecuencia como numero y Duracion como numero usando stdcall.` declares external
- `M igual CrearMotor.` opaque handle (64-bit)
- `P igual direccion de MiProc.` function pointer handle

## 17. Files, network, GPU, HTTPS
- Files (single session): `abrir/crear "ruta".`, `leer Linea.`, `escribir X.`, `cerrar.`, `eliminar "ruta".`
- TCP (single session): `conectar "host" Puerto.`, `enviar X.`, `recibir Var.`, `desconectar.`
- HTTPS one-shot: `https traer URL a Var.`
- GPU (D3D11): `gpu iniciar.`, `gpu programa "hlsl".`, `gpu ejecutar Entrada a Salida.`, `gpu terminar.`

## 18. Administrator / Services
Types: `fichero`, `socket`, `web`, `gpu`, `kernel`, `ventana`.  
Syntax: `servicio <tipo> [args] como <Nombre>.`, `inyectar <tipo> como <Nombre>.`, `administrador.`, `administrador cerrar.`  
Member ops: `leer`, `escribir`, `enviar`, `recibir`, `ejecutar`, `cerrar`, `limpiar` etc.  
Legacy forms (`abrir/crear/leer/escribir/cerrar/eliminar/conectar/...`) remain compatible (routed through admin).

## 19. 2D Window (D3D11, Windows only) [IMPLEMENTED]
Service `ventana` with member ops: `limpiar`, `color R y G y B`, `rectangulo X y Y y Ancho y Alto`, `circulo X y Y y Radio`, `linea X1 y Y1 a X2 y Y2`, `rotulo X y Y y "texto"`, `sprite "r.bmp" en X y Y`, `voltear`, `ancho`/`alto`, mouse/keyboard. On Unix fails with clear E202.

## 20. Tasks, tick, other
- `tarea ... fin.` async block
- `tick 60. ... fin.` / `tick turbo. ... fin.`
- `esperar Segs.`, `azar N`, `seno/coseno`, `pizarra/lienzo/tablero`, `puntero`

## Versioning
`VERSION` file + `--version`. Current: 1.1
