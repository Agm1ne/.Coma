# .Coma — lenguaje bilingüe (español/inglés) que compila a binarios nativos

[English](README.md) | **Español**

.Coma es un lenguaje de programación que se escribe como se habla: sin punto y coma, con palabras en español o inglés, y compila a binarios nativos rápidos (LLVM IR + `zig cc`).

```coma
Jefe igual registro Vida 30 y Ataque 5.
en caso de que Vida de Heroe es menor a 1.
    mostrar "Fin del juego.".
fin.
```

La especificación normativa está en [COMA.txt](COMA.txt). [SPEC.en.md](SPEC.en.md) es su espejo; si difieren, `COMA.txt` gana.

## Qué es / qué no es

**Qué es:**
- Bilingüe (ES/EN), normalizado a canónicos en el lexer
- Sin punto y coma, sentencias con `.`, bloques con `fin.`
- Variables con mayúscula, tipado implícito
- Funciones, recursión, listas, registros, `por_cada`, `segun`/`caso`/`otro`, bits
- FFI (`cargar` + `funcion externa`), asas, callbacks con `direccion de`
- Servicios (administrador): `servicio`, `inyectar`, `administrador` con operaciones de miembro
- Ventana 2D (D3D11, Windows), compute GPU (D3D11), TCP/HTTPS, mando, módulos `traer`
- Compilador, runtime, IDE, REPL y batería de tests

**Qué no es (límites honestos):**
- Sin hilos/paralelismo
- Sin TLS en cliente TCP (HTTPS usa Schannel en Windows)
- Sin gestor de paquetes
- Sin closures/captura real
- Los registros son entidades globales (aún no se pasan como argumento/retorno)
- Ventana 2D y GPU solo Windows (Direct3D 11)
- FFI estilo ENTER/stdcall; sin name mangling C++ en el showcase
- DI vía administrador (asas opacas), sin interfaces polimórficas de primera clase

## Inicio rápido

```bat
tools\coma-build.bat juego\mazmorra.coma
juego\mazmorra.exe
```

O abre `tools\ide\coma-ide.exe`. REPL: `tools\repl\coma-repl.bat`.

No requiere dependencias pesadas; `zig` se descarga con `tools\get-toolchain.bat` si falta.

## Estructura

```
coma/
  COMA.txt            especificación normativa (ES)
  SPEC.en.md          espejo (EN)
  README.md           inglés
  README.es.md        español
  VERSION             "1.1"
  LICENSE             MIT
  nim/coma.exe        compilador (+ fuentes)
  rt/                 runtime C portable
  lib/                librerías del lenguaje
  juego/              juegos jugables
  duelo/              benchmarks Coma vs C
  ejemplos/           ejemplos curados
  tools/              build/IDE/REPL/batería
  docs/               lanzamiento/benchmarks/limitaciones
```

## Versión
1.1
