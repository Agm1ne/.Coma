# .Coma — lenguaje de programación humano, bilingüe y de uso general

**Español** | [English](#english)

.Coma es un lenguaje de programación que se escribe como hablas: sin punto y coma, con palabras en español o inglés, y compila a binarios nativos rápidos (LLVM IR + `zig cc`). No es un juguete de scripting: es un lenguaje de **uso general** con runtime propio que incluye gráficos 2D, audio, red (TCP/HTTP/HTTPS), GPU compute, hilos, canales, FFI completa y manipulación de datos (JSON/CSV).

```coma
Jefe igual registro Vida 30 y Ataque 5.
en caso de que la Vida del Heroe es menor a 1.
    mostrar "Fin del juego.".
fin.
```

La especificación completa (viva, en español) está en [COMA.txt](COMA.txt).

## Capacidades reales

.Coma no es solo texto de consola. El runtime portable en C (`rt/`) incluye:

| Capacidad | Detalle | Archivo runtime |
|-----------|---------|-----------------|
| **Gráficos 2D** | Ventana Win32 nativa + OpenGL 3.3, framebuffer software, rectángulos, círculos, líneas, sprites BMP, fuente bitmap 8x8, detección de ratón y teclas | `rt_ventana.c`, `rt_font8x8.c`, `rt_bmp.c` |
| **Audio** | Exporta WAV (RIFF PCM 16-bit), MP3 (MPEG-1 Layer I), OGG (OggPCM) desde listas de enteros | `rt_audio.c` |
| **GPU compute** | Ejecución por CPU (single-source, in-place `out[i] = in[i] + 1`), comandos `iniciar`, `programa`, `ejecutar`, `terminar` | `rt_gpu.c` |
| **Red TCP** | Cliente con `getaddrinfo`, timeout 15s, CRLF automático. Servidor HTTP completo (`coma_srv_start/accept/read/write/close`, `coma_http_serve`, CORS, hash FNV-1a) | `rt_net.c` |
| **HTTPS** | Handshake TLS real con Schannel (Windows), validación de certificados, hasta 3 saltos HTTP, GET y POST | `rt_https.c` |
| **Hilos y paralelismo** | Hilos detached (CreateThread/pthread), actores (64 con buzones ring), canales thread-safe (mutex + semáforos), try/catch con setjmp/longjmp, `futuro`, `select` | `rt_thread.c` |
| **FFI completa** | `funcion externa ... alias "mi_funcion" usando cc. vincular "libreria"`. Convenciones: cdecl, stdcall, winapi, fastcall. Tipos: entero, decimal, texto, lista, lista_texto, lista_lista, registro, asa | `coma.nim` (codegen) |
| **Ficheros** | `abrir`/`crear`/`leer Linea.`/`escribir X.`/`cerrar.`/`eliminar "f".` Sesión única, autocierra vía atexit | `rt_fs.c` |
| **JSON** | Parser recursivo (objeto/array/str/num/bool/null), get/set, serialize | `rt_json.c` |
| **CSV** | Parser con campos comillados, filas/cols/celda | `rt_csv.c` |
| **Teclado y mando** | `Tecla` (sondeo en tiempo real, flechas→wasd), `Mando` (XInput/winmm/evdev para gamepad/guitarra GH) | `rt_win.c`, `rt_unix.c` |
| **Sistema** | `Hora`, `Fecha`, `Usuario`, `Sistema`, `Version`, `Directorio` (presets de solo lectura) | `rt_win.c`, `rt_unix.c` |

## Demostraciones incluidas

| Demo | Qué demuestra | Archivo |
|------|---------------|---------|
| **Mazmorra del Eco** | Juego de mazmorra con combate por turnos, inventario, mapa, HUD fijo, telégrafo TCP a API de bromas, ficheros de hazañas | `juego/mazmorra.coma` |
| **Tres en raya** | Ventana gráfica 2D real (OpenGL), IA que bloquea/gana, sonido vía FFI (Beep), reinicio con R, salida con Q | `juego/tictactoe.coma` |
| **Agmine Coin** | Servidor HTTP multihilo 100% en Coma: login con hash FNV-1a, bloqueo tras 3 fallos, saldo/minar/comprar/registro, chat, frontend web | `webdemo/servidor.coma` |
| **Duelo vs C** | 3 benchmarks (suma, búsqueda, tablero) que compilan y ejecutan igual que C | `duelo/` |

## Estructura

```
coma/
  COMA.txt            especificación del lenguaje (documento vivo, 365 líneas)
  README.md           este archivo
  LICENSE             licencia MIT
  VERSION             "1.1"
  nim/coma.exe        compilador listo para usar (+ fuentes .nim)
  rt/                 runtime portable en C (Windows + Unix, 16 archivos .c)
  lib/                librerías dentro del lenguaje (motor.coma con FFI a AgmineEditor)
  juego/              mazmorra.coma + mazmorra_en.coma + tictactoe.coma jugables
  ejemplos/           15 ejemplos básicos (listas, registros, funciones, etc.)
  duelo/              benchmarks Coma vs C (suma, búsqueda, tablero)
  bug_tracking/       235 ejemplos organizados en 8 categorías (rastreo de bugs y features)
  tools/
    coma-build.bat    compila cualquier .coma en un comando
    ide/              coma-ide.exe: editor + LSP en vivo + diccionario + diario
    repl/             REPL de consola en un archivo temporal
    bateria/          suite de 58 tests automáticos
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

**8. Ventana gráfica 2D** → abre ventana real con OpenGL
```coma
lienzo 40 y 40.
marca 10 y 10 con X.
marca 20 y 20 con O.
mostrar "Tablero renderizado.".
```

**9. Audio** → exporta WAV/MP3/OGG
```coma
Muestras igual lista 1000 y 2000 y 3000.
audio exportar Muestras y "prueba.wav".
```

**10. Red** → conecta a servidor TCP
```coma
conectar "localhost" y 8080.
enviar "Hola servidor".
recibir Respuesta.
mostrar Respuesta.
desconectar.
```

**11. GPU compute**
```coma
gpu iniciar.
Entrada igual lista 1 y 2 y 3 y 4 y 5.
Salida igual lista.
gpu programa "out = in + 1.".
gpu ejecutar Entrada y Salida.
mostrar elemento 1 de Salida.
gpu terminar.
```

**12. Hilos y canales**
```coma
canal crear C1.
canal enviar 42 a C1.
canal recibir X de C1.
mostrar X.
```

¿Siguiente paso? Abre `juego/mazmorra.coma`: es todo esto junto en un juego real. O `webdemo/servidor.coma`: un servidor web completo.

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

.Coma is a programming language you write the way you speak: no semicolons, words in Spanish or English, compiling to fast native binaries (LLVM IR + `zig cc`). It is **not** a scripting toy: it is a **general-purpose language** with its own runtime that includes 2D graphics, audio, networking (TCP/HTTP/HTTPS), GPU compute, threads, channels, full FFI and data manipulation (JSON/CSV).

```coma
Boss equal record Health 30 and Attack 5.
if the Health of the Hero is less than 1.
    print "Game over.".
end.
```

The full spec (living document, in Spanish) is in [COMA.txt](COMA.txt).

## Capabilities

.Coma is not just console text. The portable C runtime (`rt/`) includes:

| Capability | Detail | Runtime file |
|------------|--------|--------------|
| **2D Graphics** | Native Win32 window + OpenGL 3.3, software framebuffer, rectangles, circles, lines, BMP sprites, 8x8 bitmap font, mouse and keyboard detection | `rt_ventana.c`, `rt_font8x8.c`, `rt_bmp.c` |
| **Audio** | Exports WAV (RIFF PCM 16-bit), MP3 (MPEG-1 Layer I), OGG (OggPCM) from integer lists | `rt_audio.c` |
| **GPU compute** | CPU-executed (single-source, in-place `out[i] = in[i] + 1`), commands `start`, `program`, `run`, `finish` | `rt_gpu.c` |
| **TCP Network** | Client with `getaddrinfo`, 15s timeout, automatic CRLF. Full HTTP server (`coma_srv_start/accept/read/write/close`, `coma_http_serve`, CORS, FNV-1a hash) | `rt_net.c` |
| **HTTPS** | Real TLS handshake with Schannel (Windows), certificate chain validation, up to 3 HTTP hops, GET and POST | `rt_https.c` |
| **Threads and parallelism** | Detached threads (CreateThread/pthread), actors (64 with ring buffers), thread-safe channels (mutex + semaphores), try/catch with setjmp/longjmp, `future`, `select` | `rt_thread.c` |
| **Full FFI** | `function external ... alias "symbol" using cc. link "library"`. Conventions: cdecl, stdcall, winapi, fastcall. Types: integer, decimal, text, list, text_list, list_list, record, asa | `coma.nim` (codegen) |
| **Files** | `open`/`create`/`read Line.`/`write X.`/`close.`/`delete "f".` Single session, auto-close via atexit | `rt_fs.c` |
| **JSON** | Recursive parser (object/array/str/num/bool/null), get/set, serialize | `rt_json.c` |
| **CSV** | Parser with quoted fields, rows/cols/cell | `rt_csv.c` |
| **Keyboard and gamepad** | `Key` (real-time polling, arrows→wasd), `Pad` (XInput/winmm/evdev for gamepad/GH guitar) | `rt_win.c`, `rt_unix.c` |
| **System** | `Time`, `Date`, `User`, `System`, `Version`, `Directory` (read-only presets) | `rt_win.c`, `rt_unix.c` |

## Included demos

| Demo | What it demonstrates | File |
|------|----------------------|------|
| **Mazmorra del Eco** | Dungeon game with turn-based combat, inventory, map, fixed HUD, TCP telegraph to joke API, feat files | `juego/mazmorra.coma` |
| **Tic-tac-toe** | Real 2D graphical window (OpenGL), blocking/winning AI, sound via FFI (Beep), restart with R, exit with Q | `juego/tictactoe.coma` |
| **Agmine Coin** | Multithreaded HTTP server 100% in Coma: login with FNV-1a hash, lockout after 3 failures, balance/mine/buy/register, chat, web frontend | `webdemo/servidor.coma` |
| **Duel vs C** | 3 benchmarks (sum, search, board) that compile and run like C | `duelo/` |

## Layout

```
coma/
  COMA.txt            language specification (living document, 365 lines)
  README.md           this file
  LICENSE             MIT license
  VERSION             "1.1"
  nim/coma.exe        ready-to-use compiler (+ .nim sources)
  rt/                 portable C runtime (Windows + Unix, 16 .c files)
  lib/                in-language libraries (motor.coma with FFI to AgmineEditor)
  juego/              playable mazmorra.coma + mazmorra_en.coma + tictactoe.coma
  ejemplos/           15 basic examples (lists, records, functions, etc.)
  duelo/              Coma vs C benchmarks (sum, search, board)
  bug_tracking/       235 examples organized in 8 categories (bug and feature tracking)
  tools/
    coma-build.bat    builds any .coma in one command
    ide/              coma-ide.exe: editor + live LSP + dictionary + diary
    repl/             single-temp-file console REPL
    bateria/          58 automatic tests
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

**8. 2D graphical window** → opens real window with OpenGL
```coma
canvas 40 and 40.
mark 10 and 10 with X.
mark 20 and 20 with O.
print "Board rendered.".
```

**9. Audio** → exports WAV/MP3/OGG
```coma
Samples equal list 1000 and 2000 and 3000.
audio export Samples and "test.wav".
```

**10. Network** → connects to TCP server
```coma
connect "localhost" and 8080.
send "Hello server".
receive Response.
print Response.
disconnect.
```

**11. GPU compute**
```coma
gpu start.
Input equal list 1 and 2 and 3 and 4 and 5.
Output equal list.
gpu program "out = in + 1.".
gpu run Input and Output.
print element 1 of Output.
gpu finish.
```

**12. Threads and channels**
```coma
channel create C1.
channel send 42 to C1.
channel receive X from C1.
print X.
```

Next step? Open `juego/mazmorra.coma`: all of this together in a real game. Or `webdemo/servidor.coma`: a complete web server.

## Vendoring Coma into your project

1. Copy the `coma/` folder into your project.
2. Build your `.coma` files with `coma/tools/coma-build.bat` (or `coma/nim/coma.exe` directly).
3. Programs only link `coma/rt/*.c` (libc + `ws2_32` on Windows).

With the Nim toolchain you can rebuild the compiler:

```bat
nim c -d:release --cc:gcc --gcc.exe:"nim\zigcc.bat" --gcc.linkerexe:"nim\zigcc.bat" nim/coma.nim
```