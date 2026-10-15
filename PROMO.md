# PROMO — lanzamiento v1.0 de .Coma (borrador, no es parte del lenguaje)

Repo: https://github.com/Agm1ne/.Coma — Licencia MIT.

## Post EN (r/ProgrammingLanguages) — FINAL, listo para pegar

**Title:** Coma: a bilingual (Spanish/English) programming language that ties C and reads like prose

**Body:**

Hi! I built **.Coma**, a language with a strange bet: prose ergonomics with native performance. No semicolons, hundreds of colloquial synonyms, articles you can skip (`the`, `la`, `del`) — and it still compiles through its own Nim frontend to LLVM IR + `zig cc`, measured against C.

Same program, two languages, one binary:

```coma
Hero equal record Life 12 and Attack 2.
if the Life of the Hero is less than 1.
    print "Game over.".
end.
```

```coma
Heroe igual registro Vida 12 y Ataque 2.
de en caso de que la Vida de el Heroe es menor a 1.
    mostrar "Fin del juego.".
fin.
```

What v1.0 actually does (all verified running): record lists with row access (`Life of element 2 of Enemies`), unbounded heap lists (ints, text, nested matrices), single-session files + TCP (it fetches a real joke over HTTP), 60 FPS ticks with delta time, built-in tests, case-insensitive comparison, hex + bit operators, and an IDE in a single .exe with live diagnostics and GameMaker-style autocomplete.

Honest limits, all documented: no threads yet, TCP client without TLS, no package manager, no FFI on purpose (everything is a native primitive).

MIT licensed, Windows + Linux. And there's a playable dungeon crawler written in it (`juego/mazmorra.coma`, EN+ES).

Repo: https://github.com/Agm1ne/.Coma

What would you build in a language that reads like prose?

---

## Post ES (r/programacion)

**Título:** Hice .Coma, un lenguaje que se escribe como hablas (ES/EN) y compila a binario nativo

**Cuerpo:**

¡Hola! Hice **.Coma**, un lenguaje con una apuesta rara: ergonomía de prosa (sin punto y coma, cientos de sinónimos coloquiales, programas que se leen como un libro) con **rendimiento nativo** (frontend propio en Nim → LLVM IR → `zig cc`, medido contra C, ganando en su nicho de consola).

```coma
Heroe igual registro Vida 12 y Ataque 2.
de en caso de que la Vida de el Heroe es menor a 1.
    mostrar "Fin del juego.".
fin.
```

Lo mismo, en inglés, compilando al mismo binario. Artículos (`la`, `el`, `the`) y preposiciones (`del`, `al`) se ignoran; `menor a` vale sin el `es`.

Lo que trae la v1.0: `comprobar` para tests, listas de texto y matrices sin topes, ficheros y red TCP en sesión única, ticks a 60 FPS con delta time, hexadecimal + bits, presets del sistema en vivo, y un IDE en un solo .exe con diagnósticos en tiempo real.

Límites honestos: sin hilos todavía, TCP cliente sin TLS, sin gestor de paquetes. Todo documentado en COMA.txt.

Licencia MIT, Windows + Linux. Y hay una mazmorra jugable escrita en él (`juego/mazmorra.coma`).

Repo: https://github.com/Agm1ne/.Coma

¿Qué harías tú en un lenguaje que se lee como prosa?

---

## Pre-flight checklist v1.0

- [ ] `git init` + primer commit en https://github.com/Agm1ne/.Coma
- [ ] LICENSE (MIT) en la raíz ✓ (ya está en `coma/LICENSE`)
- [ ] README con tutorial verificado ✓ (ya está en `coma/README.md`)
- [ ] Release v1.0 con binarios: `nim/coma.exe` + `tools/ide/coma-ide.exe` + `juego/mazmorra.exe` + `juego/mazmorra_en.exe`
- [ ] Capturas: IDE con autocompletado + mazmorra corriendo (una ES, una EN)
- [ ] Video corto (30-60 s): escribir `mue` + Tab en el IDE, compilar y jugar 10 s
- [ ] Publicar EN: r/ProgrammingLanguages (mar-jue, mañana USA). ES: r/programacion
- [ ] Responder los primeros comentarios el mismo día (algoritmo mediante)

## Comandos del lanzamiento

```bat
cd coma
git init
git add COMA.txt README.md LICENSE .gitignore nim\*.nim rt\* lib\*.coma juego\mazmorra.coma juego\mazmorra_en.coma juego\jugar_mazmorra.ps1 tools\ -f nim\coma.exe tools\ide\coma-ide.exe
git commit -m "v1.0: el lenguaje que se escribe como hablas"
git branch -M main
git remote add origin https://github.com/Agm1ne/.Coma.git
git push -u origin main
```
