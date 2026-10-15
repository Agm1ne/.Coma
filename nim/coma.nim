# coma.nim — Frontend y driver de compilación del lenguaje .Coma
import os, parseopt, strutils, tables
import src/ast, src/lexer, src/parser, src/sema, src/codegen, src/opt

const
  Version = "0.9.0"
  Usage = """
.Coma v""" & Version & """ — Compilador portable para el lenguaje Coma.
Uso:
  coma.exe archivo.coma [opciones]

Opciones:
  --ir                  Genera solo el archivo LLVM IR (.ll) sin compilar el binario
  --opt:N               Nivel de optimizacion para zig cc: 0, 2 o 3 (defecto: 2)
  --target:TRIPLE       Tripleta zig (p.ej. x86_64-linux, x86_64-windows-gnu).
                        Elige el runtime coma/rt (win/unix) y se la pasa a zig cc
  --salida:NOMBRE, -o   Nombre del binario resultante (defecto: archivo.exe)
  --version, -v         Muestra la version
  --ayuda, -h           Muestra esta ayuda
"""

proc printIssue(iss: Issue, srcLines: seq[string]) =
  let prefix = case iss.level
    of eError: "error"
    of eWarning: "aviso"
    of eNote: "nota"
  echo "linea ", iss.line, ":", iss.col, " [", iss.code, " ", prefix, "]: ", iss.msg
  if iss.line > 0 and iss.line <= srcLines.len:
    echo "  ", srcLines[iss.line - 1]
    echo "  ", repeat(' ', max(0, iss.col - 1)), "^~~~"
  if iss.hint.len > 0:
    echo "  sugerencia: ", iss.hint

proc findRtDir(): string =
  ## Carpeta coma/rt junto al compilador (o alternativas honestas).
  var cands: seq[string] = @[]
  try:
    cands.add(parentDir(parentDir(getAppFilename())) / "rt")
  except:
    discard
  cands.add(getCurrentDir() / "coma" / "rt")
  cands.add(getCurrentDir() / "rt")
  for d in cands:
    if dirExists(d):
      return d
  return ""

proc collectTraer(n: Node, outSeq: var seq[Node]) =
  if n == nil: return
  if n.kind == nkTraer:
    outSeq.add(n)
    return
  case n.kind
  of nkProgram, nkBlock:
    for c in n.children: collectTraer(c, outSeq)
  else:
    if n.thenBlock != nil: collectTraer(n.thenBlock, outSeq)
    if n.elseBlock != nil and n.elseBlock.kind in {nkBlock, nkIf}:
      collectTraer(n.elseBlock, outSeq)
    for c in n.children: collectTraer(c, outSeq)

proc comaRoot(): string =
  try:
    let r = parentDir(parentDir(getAppFilename()))
    if dirExists(r / "rt") or dirExists(r / "lib"): return r
  except:
    discard
  if dirExists(getCurrentDir() / "coma" / "lib"): return getCurrentDir() / "coma"
  return ""

proc findModule(modName, baseDir, rootDir: string): string =
  let f = modName.toLowerAscii() & ".coma"
  var cands: seq[string] = @[]
  if baseDir.len > 0: cands.add(baseDir / f)
  if rootDir.len > 0: cands.add(rootDir / "lib" / f)
  cands.add(getCurrentDir() / "coma" / "lib" / f)
  for c in cands:
    if fileExists(c): return c
  return ""

proc fileFuncNames(path: string): seq[string] =
  try:
    var iss: seq[Issue] = @[]
    return scanFuncNames(tokenize(readFile(path), iss))
  except:
    return @[]

proc renameCalls(n: Node, mapping: Table[string, string], skip: seq[string],
                 ambig: Table[string, seq[string]]) : bool =
  ## Reescribe nkCall.funcName según mapa (recursivo total: cond/args/campos).
  ## Llamada ambigua (dos módulos, sin local): error honesto y true.
  if n == nil: return false
  if n.kind == nkCall:
    if n.funcName in skip:
      discard
    elif mapping.hasKey(n.funcName):
      n.funcName = mapping[n.funcName]
    elif ambig.hasKey(n.funcName):
      echo "linea ", n.line, ":", n.col, " [E003 error]: '", n.funcName,
           "' viene de varios modulos (", ambig[n.funcName].join(" y "), "): calificalo"
      echo "  sugerencia: renombra tu funcion local igual que el modulo"
      return true
  if n.thenBlock != nil:
    if renameCalls(n.thenBlock, mapping, skip, ambig): return true
  if n.elseBlock != nil and n.elseBlock.kind in {nkBlock, nkIf}:
    if renameCalls(n.elseBlock, mapping, skip, ambig): return true
  if n.cond != nil:
    if renameCalls(n.cond, mapping, skip, ambig): return true
  if n.left != nil:
    if renameCalls(n.left, mapping, skip, ambig): return true
  if n.right != nil:
    if renameCalls(n.right, mapping, skip, ambig): return true
  if n.target != nil:
    if renameCalls(n.target, mapping, skip, ambig): return true
  for a in n.args:
    if renameCalls(a, mapping, skip, ambig): return true
  for f in n.fields:
    if renameCalls(f.val, mapping, skip, ambig): return true
  case n.kind
  of nkProgram, nkBlock, nkFuncDecl, nkMatch, nkCaseBranch,
     nkMostrar, nkListLit, nkListRecordLit:
    for c in n.children:
      if renameCalls(c, mapping, skip, ambig): return true
    if n.kind == nkListRecordLit:
      for r in n.children:
        if r != nil and r.kind == nkRecordLit:
          for f in r.fields:
            if renameCalls(f.val, mapping, skip, ambig): return true
  else: discard
  return false

proc fileTraerRefs(path: string): seq[tuple[name: string, line, col: int]] =
  ## Pares (nombre, linea, col) de cada `traer X` por tokens (sin parsear).
  try:
    var iss: seq[Issue] = @[]
    let toks = tokenize(readFile(path), iss)
    var i = 0
    while i < toks.len:
      if toks[i].kind == tokKeyword and toks[i].val == "traer" and
         i + 1 < toks.len and toks[i+1].kind in {tokIdent, tokKeyword}:
        result.add((toks[i+1].val, toks[i].line, toks[i].col))
        i += 2
      else: inc i
  except:
    discard

proc compileFile(srcPath: string, emitIR: bool, optLevel: int, outBin: string,
                 target: string): int =
  if not fileExists(srcPath):
    echo "Error: no se encuentra el archivo '", srcPath, "'"
    return 1

  let srcCode = readFile(srcPath)
  let srcLines = srcCode.splitLines()
  var allIssues: seq[Issue] = @[]

  # 1. Lexer (sus issues sí valen desde ya)
  let tokens = tokenize(srcCode, allIssues)

  # 2. Parser en dos pasadas (la 1 no sentencia: puede fallar en llamadas
  # a funciones de módulos aún sin resolver).
  var hasErrors = false
  var issues1: seq[Issue] = @[]
  let ast1 = parseProgram(tokens, issues1)

  # 2b. Módulos traer: se resuelve el conjunto de ficheros (BFS por tokens,
  # anti-ciclos) y la tabla completa de firmas. Pasada 2: se reparsea el
  # principal con todas las firmas (valen llamadas sin args a funciones de
  # módulos aunque se definan después o en otro archivo).
  # Solo declaraciones (funcion/registro) entran; el código suelto del
  # módulo no se ejecuta al importar (límite honesto v1).
  let (sdir, _, _) = splitFile(srcPath)
  let baseDir = if sdir.len > 0: sdir else: getCurrentDir()
  let rootDir = comaRoot()
  var seenMods: seq[string] = @[]
  var queue: seq[tuple[name: string, line, col: int, fromFile: string]] = @[]
  var tmpTraer: seq[Node] = @[]
  collectTraer(ast1, tmpTraer)
  for t in tmpTraer:
    queue.add((t.funcName, t.line, t.col, srcPath))
  var mainFuncs = scanFuncNames(tokens)
  var allNames = mainFuncs
  var modPaths: seq[string] = @[]
  var modKeys: seq[string] = @[]
  var modFail = false
  while queue.len > 0 and not modFail:
    let q = queue.pop()
    let key = q.name.toLowerAscii()
    if key in seenMods: continue
    seenMods.add(key)
    let mp = findModule(q.name, baseDir, rootDir)
    if mp.len == 0:
      echo "en ", q.fromFile, " linea ", q.line, ":", q.col, " [E001 error]: no existe el modulo '", q.name, "' (busque junto al fuente y en coma/lib)"
      echo "  sugerencia: crea coma/lib/", key, ".coma"
      modFail = true
      break
    modPaths.add(mp)
    modKeys.add(key)
    for f in fileFuncNames(mp):
      if f notin allNames: allNames.add(f)
    for r in fileTraerRefs(mp):
      queue.add((r.name, r.line, r.col, mp))
  if modFail:
    return 1
  # Mangle: cada funcion de módulo vive como modulo__F (conviven homónimos;
  # el main manda en local; dos módulos con la misma = ambiguo honesto).
  # allNames lleva originales + manglados (las llamadas escuetas parsean).
  var modOwn = initTable[string, seq[string]]()
  for i, mp in modPaths:
    modOwn[modKeys[i]] = fileFuncNames(mp)
  var owners = initTable[string, seq[string]]()
  for i, mp in modPaths:
    for f in modOwn[modKeys[i]]:
      if f in mainFuncs: continue
      if not owners.hasKey(f): owners[f] = @[]
      if modKeys[i] notin owners[f]: owners[f].add(modKeys[i])
  var merged = initTable[string, string]()
  var ambig = initTable[string, seq[string]]()
  for f, ks in owners:
    if ks.len == 1:
      merged[f] = ks[0] & "__" & f
    else:
      ambig[f] = ks
  for v in merged.values:
    if v notin allNames: allNames.add(v)
  var modDecls: seq[Node] = @[]
  for i, mp in modPaths:
    let key = modKeys[i]
    var miss: seq[Issue] = @[]
    let mtoks = tokenize(readFile(mp), miss)
    let mroot = parseProgram(mtoks, miss, allNames)
    var bad = false
    for iss in miss:
      if iss.level == eError: bad = true
      echo "en ", mp, " linea ", iss.line, ":", iss.col, " [", iss.code, "]: ", iss.msg
    if bad:
      echo "Compilacion abortada: el modulo tiene errores."
      return 1
    var ownMap = initTable[string, string]()
    for f in modOwn[key]:
      ownMap[f] = key & "__" & f
    for s in mroot.children:
      if s.kind == nkFuncDecl and s.funcName in modOwn[key]:
        s.funcName = key & "__" & s.funcName
        if renameCalls(s, ownMap, @[], ambig):
          return 1
        modDecls.add(s)
      elif s.kind == nkRecordBlock:
        modDecls.add(s)
  # Pasada 2 del principal con la tabla completa (estos issues sí valen,
  # junto a los del lexer). Sus llamadas a módulos se manglan salvo
  # locales; las ambiguas abortan honesto en renameCalls.
  let astRoot = parseProgram(tokens, allIssues, allNames)
  if renameCalls(astRoot, merged, mainFuncs, ambig):
    return 1
  astRoot.children = modDecls & astRoot.children
  for iss in allIssues:
    if iss.level == eError:
      hasErrors = true
    printIssue(iss, srcLines)
  if hasErrors:
    echo "Compilacion abortada por errores sintacticos."
    return 1

  # 2c. Optimizaciones propias (plegado + propagación; lo que C no hace por ti).
  optimizeProgram(astRoot)

  # 3. Semántica
  let semaCtx = analyzeSemantics(astRoot, allIssues)
  for iss in semaCtx.issues:
    if iss.level == eError:
      hasErrors = true
    printIssue(iss, srcLines)

  if hasErrors:
    echo "Compilacion abortada por errores semanticos."
    return 1

  # 4. Generación de LLVM IR
  let llvmIR = generateIR(astRoot, semaCtx)
  let (dir, name, _) = splitFile(srcPath)
  let llPath = if dir.len > 0: dir / (name & ".ll") else: name & ".ll"
  writeFile(llPath, llvmIR)
  echo "OK: LLVM IR generado en '", llPath, "'"

  if emitIR:
    return 0

  # 5. Backend: invocar zig cc enlazando el runtime portable coma/rt
  let exePath = if outBin.len > 0: outBin else: (if dir.len > 0: dir / (name & ".exe") else: name & ".exe")
  let rtDir = findRtDir()
  if rtDir.len == 0:
    echo "Error: no se encuentra coma/rt (runtime portable). Reinstala el compilador."
    return 1
  let lowT = target.toLowerAscii()
  let wantWin = if lowT.len == 0:
                  when defined(windows): true else: false
                elif "windows" in lowT: true
                elif "linux" in lowT or "macos" in lowT or "darwin" in lowT: false
                else:
                  when defined(windows): true else: false
  let rtFile = if wantWin: rtDir / "rt_win.c" else: rtDir / "rt_unix.c"
  let rtFs = rtDir / "rt_fs.c"
  let rtNet = rtDir / "rt_net.c"
  if not fileExists(rtFile):
    echo "Error: falta el runtime '", rtFile, "'"
    return 1
  if not fileExists(rtFs):
    echo "Error: falta el runtime '", rtFs, "'"
    return 1
  if not fileExists(rtNet):
    echo "Error: falta el runtime '", rtNet, "'"
    return 1
  let tgtFlag = if target.len > 0: " -target " & target else: ""
  let libFlag = if wantWin: " -lws2_32" else: ""
  let zigCmd = "zig cc" & tgtFlag & " -O" & $optLevel & " \"" & llPath & "\" \"" & rtFile & "\" \"" & rtFs & "\" \"" & rtNet & "\"" & libFlag & " -o \"" & exePath & "\""
  echo "Compilando nativo: ", zigCmd
  let res = execShellCmd(zigCmd)
  if res == 0:
    echo "Binario generado exitosamente: '", exePath, "'"
    return 0
  else:
    echo "Error al invocar zig cc (codigo ", res, ")."
    return res

proc main() =
  var srcFile = ""
  var emitIR = false
  var optLevel = 2
  var outBin = ""
  var target = ""

  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key.toLowerAscii()
      of "ir":
        emitIR = true
      of "opt":
        optLevel = parseInt(p.val)
      of "target":
        target = p.val
      of "salida", "o":
        outBin = p.val
      of "version", "v":
        echo ".Coma compilador v", Version
        quit(0)
      of "ayuda", "h", "help":
        echo Usage
        quit(0)
      else:
        echo "Opcion desconocida: --", p.key
        quit(1)
    of cmdArgument:
      if srcFile.len == 0:
        srcFile = p.key

  if srcFile.len == 0:
    echo Usage
    quit(1)

  quit(compileFile(srcFile, emitIR, optLevel, outBin, target))

when isMainModule:
  main()
