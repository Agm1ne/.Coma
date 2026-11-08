# Toolchain portable

Esta carpeta es donde vive el **toolchain de LLVM (zig)** que usa `.Coma` para
convertir el IR generado en un binario nativo.

**El usuario no tiene que instalar nada.** Basta con ejecutar una vez:

```bat
tools\get-toolchain.bat      (Windows)
sh tools/get-toolchain.sh    (Linux/macOS)
```

El script descarga una versión fijada de zig, **verifica su SHA256** y lo
desempaqueta en `tools/toolchain/zig/`. A partir de ahí el compilador lo
encuentra solo (misma política que el runtime `coma/rt/`: se busca a partir
de la ruta del propio `coma.exe`).

## Orden de búsqueda del backend

1. `COMA_CC` — variable de entorno; se usa tal cual, sin tocarlo. Para quien
   sepa lo que hace.
2. `tools/toolchain/zig/zig.exe` — el toolchain portable de este repo.
3. `zig` en el `PATH`.
4. `clang` en el `PATH` — solo en Linux/macOS y sin `--target` (en Windows el
   modo por defecto de clang es MSVC y no acepta los `-l` que usa el runtime).

Si no hay ninguno, el compilador lo dice con un mensaje que explica
exactamente qué ejecutar.

## ¿Por qué no va esto en git?

Son ~100 MB por plataforma. El repo versiona el **código**; el binario se
descarga con un comando y con checksum verificado. La release de GitHub sí
incluye un `.zip` portable con el toolchain dentro, para quien quiera
funcionar sin conexión.

## Nota para el desarrollador

El repo **no** necesita este toolchain para compilar el propio compilador:
`nim\coma.exe` va versionado. Nim solo hace falta si quieres recompilar el
frontend:

```bat
nim c -d:release --cc:gcc --gcc.exe:"nim\zigcc.bat" --gcc.linkerexe:"nim\zigcc.bat" nim/coma.nim
```
