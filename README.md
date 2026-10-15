# .Coma — lenguaje de programación humano y bilingüe

**Español** | [English](#english)

.Coma es un lenguaje de programación que se escribe como hablas: sin punto y coma, con palabras en español o inglés, y compila a binarios nativos rápidos (LLVM IR + `zig cc`).

```coma
Jefe igual registro Vida 30 y Ataque 5.
en caso de que la Vida del Heroe es menor a 1.
    mostrar "Fin del juego.".
fin.
```

La especificación completa (viva, en español) está en [COMA.txt](COMA.txt).

## Estructura

```
coma/
  COMA.txt            especificación del lenguaje (documento vivo)
  README.md           este archivo
  LICENSE             licencia MIT
  nim/coma.exe        compilador listo para usar (+ fuentes .nim)
  rt/                 runtime portable en C (Windows + Unix)
  lib/                librerías dentro del lenguaje (mando, guitarra)
  juego/              mazmorra.coma + mazmorra_en.coma jugables + lanzador
  duelo/              benchmarks Coma vs C
  spikes/             prototipos del compilador
  tools/
    coma-build.bat    compila cualquier .coma en un comando
    ide/              coma-ide.exe: editor + LSP en vivo + diccionario + diario
    repl/             REPL de consola en un archivo temporal
```

## Uso rápido

```bat
tools\coma-build.bat juego\mazmorra.coma
juego\mazmorra.exe
```

O abre `tools\ide\coma-ide.exe`: editor con autocompletado, diagnósticos en tiempo real, diccionario ES/EN y botón de guardar diario. Para la consola: `tools\repl\coma-repl.bat`.

Solo necesitas `zig` en el PATH. Sin dependencias pesadas.

## Tutorial básico

Todo termina en punto (`.`). Las variables empiezan en mayúscula y se crean solas al asignarlas.

**1. Mostrar texto** → imprime `Hola, mundo.`
```coma
mostrar "Hola, mundo.".
```

**2. Variables con `igual`** → imprime `50`
```coma
Precio igual 25.
Doble igual Precio mas Precio.
mostrar Doble.
```

**3. Pedir al usuario** (escribe `heroe` + enter)
```coma
mostrar "Como te llamas?".
pedir Nombre.
mostrar Nombre.
```

**4. Condiciones** → imprime `Vivo.`
```coma
Vida igual 3.
en caso de que Vida es menor a 1.
    mostrar "Muerto.".
sino.
    mostrar "Vivo.".
fin.
```

**5. Bucles** → imprime `1 2 3`
```coma
Turno igual 1.
mientras Turno es menor a 4.
    mostrar Turno.
    Turno igual Turno mas 1.
fin.
```

**6. Listas** (empiezan en 1) → imprime `pan queso vino`
```coma
Mochila igual lista "pan" y "queso".
Agregar "vino" a Mochila.
por cada E en Mochila.
    mostrar E.
fin.
```

**7. Funciones** → imprime `8`
```coma
funcion Sumar A y B.
    devolver A mas B.
fin.
mostrar Sumar 3 y 5.
```

¿Siguiente paso? Abre `juego/mazmorra.coma`: es todo esto junto en un juego real.

## Incluir Coma en tu proyecto

1. Copia la carpeta `coma/` dentro de tu proyecto.
2. Compila tus `.coma` con `coma/tools/coma-build.bat` (o `coma/nim/coma.exe` directo).
3. Los programas solo enlazan `coma/rt/*.c` (libc + `ws2_32` en Windows).

Si tienes el toolchain de Nim, puedes reconstruir el compilador:

```bat
nim c -d:release --cc:gcc --gcc.exe:"nim\zigcc.bat" --gcc.linkerexe:"nim\zigcc.bat" nim/coma.nim
```

---

## English

.Coma is a programming language you write the way you speak: no semicolons, words in Spanish or English, compiling to fast native binaries (LLVM IR + `zig cc`).

```coma
Boss equal record Health 30 and Attack 5.
if the Health of the Hero is less than 1.
    print "Game over.".
end.
```

The full spec (living document, in Spanish) is in [COMA.txt](COMA.txt).

## Layout

```
coma/
  COMA.txt            language specification (living document)
  README.md           this file
  LICENSE             MIT license
  nim/coma.exe        ready-to-use compiler (+ .nim sources)
  rt/                 portable C runtime (Windows + Unix)
  lib/                in-language libraries (pad, guitar)
  juego/              playable mazmorra.coma + mazmorra_en.coma + launcher
  duelo/              Coma vs C benchmarks
  spikes/             compiler prototypes
  tools/
    coma-build.bat    builds any .coma in one command
    ide/              coma-ide.exe: editor + live LSP + dictionary + diary
    repl/             single-temp-file console REPL
```

## Quick start

```bat
tools\coma-build.bat juego\mazmorra.coma
juego\mazmorra.exe
```

Or open `tools\ide\coma-ide.exe`: editor with autocomplete, live diagnostics, ES/EN dictionary and diary button. For the console: `tools\repl\coma-repl.bat`.

You only need `zig` on PATH. No heavy dependencies.

## Basic tutorial

Everything ends with a dot (`.`). Variables start uppercase and declare themselves on assignment.

**1. Print text** → prints `Hello, world.`
```coma
print "Hello, world.".
```

**2. Variables with `equal`** → prints `50`
```coma
Price equal 25.
Double equal Price plus Price.
print Double.
```

**3. Ask the user** (type `hero` + enter)
```coma
print "What is your name?".
ask Name.
print Name.
```

**4. Conditions** → prints `Alive.`
```coma
Health equal 3.
if the Health is less than 1.
    print "Dead.".
else.
    print "Alive.".
end.
```

**5. Loops** → prints `1 2 3`
```coma
Turn equal 1.
while Turn is less than 4.
    print Turn.
    Turn equal Turn plus 1.
end.
```

**6. Lists** (start at 1) → prints `bread cheese wine`
```coma
Pack equal list "bread" and "cheese".
append "wine" to Pack.
for each E in Pack.
    print E.
end.
```

**7. Functions** → prints `8`
```coma
function Add A and B.
    return A plus B.
end.
print Add 3 and 5.
```

Next step? Open `juego/mazmorra.coma`: all of this together in a real game.

## Vendoring Coma into your project

1. Copy the `coma/` folder into your project.
2. Build your `.coma` files with `coma/tools/coma-build.bat` (or `coma/nim/coma.exe` directly).
3. Programs only link `coma/rt/*.c` (libc + `ws2_32` on Windows).

With the Nim toolchain you can rebuild the compiler:

```bat
nim c -d:release --cc:gcc --gcc.exe:"nim\zigcc.bat" --gcc.linkerexe:"nim\zigcc.bat" nim/coma.nim
```
