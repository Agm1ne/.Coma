# codegen.nim — Generador de LLVM IR con tipos reales para .Coma
# v0.6: strings ([256 x i8]), floats (double), records (globals por campo),
#       listas (array [64 x i32] + len), tablero 40x40x8, Tecla/Delta/Tiempo reales.
import tables, strutils
import ast, sema

const MaxList = 64
const StrBuf = 256
const BoardMax = 40
const BoardCells = 1600
const CellBytes = 8
const BoardBytes = 12800
const FrameBytes = 12900 # 40 filas * (40 celdas * 8 B + salto) + margen

type
  CodeGen* = object
    semaCtx*: SemaContext
    lines*: seq[string]
    tempId*: int
    labelId*: int
    strConsts*: Table[string, string]
    strCounter*: int
    globals*: Table[string, string]   # var int/bool -> @g_X
    floatGlobals*: Table[string, string] # var float -> @g_X
    strGlobals*: Table[string, string]   # var string -> @g_X
    recFields*: Table[string, string]    # "Rec.Campo" -> @g_Rec_Campo
    recFieldTyps*: Table[string, DataTypeKind]
    lists*: Table[string, string]        # lista -> @g_L (%CList)
    slists*: Table[string, string]       # lista de texto -> @g_L (%CListStr)
    llists*: Table[string, string]       # lista de listas -> @g_M (%CListList)
    rlists*: Table[string, string]       # lista de registros -> @g_G (%CRecList)
    recIters*: Table[string, string]     # iterador por_cada -> lista de registros
    locals*: Table[string, string]
    localTyps*: Table[string, DataTypeKind]
    inFunction*: bool
    curFuncName*: string
    curRetTyp*: DataTypeKind
    curRetBuf*: string
    curFreeStr*: seq[string]
    curFreeList*: seq[string]
    curFreeSList*: seq[string]
    curFreeLList*: seq[string]
    breakStack*: seq[string]
    continueStack*: seq[string]
    breakLabels*: Table[string, string]
    contLabels*: Table[string, string]
    # Cierre: nombre de variable capturada -> global del entorno (@closure_Padre_Hija_Var).
    curCaptured*: Table[string, string]
    # Variables elevadas a global porque alguna función anidada las captura.
    capturedGlobals*: Table[string, DataTypeKind]
    usesBoard*: bool
    usesTecla*: bool
    usesTime*: bool
    usesAgmine*: bool

proc newCodeGen*(semaCtx: SemaContext): CodeGen =
  result.semaCtx = semaCtx
  result.lines = @[]
  result.tempId = 0
  result.labelId = 0
  result.strConsts = initTable[string, string]()
  result.strCounter = 0
  result.globals = initTable[string, string]()
  result.floatGlobals = initTable[string, string]()
  result.strGlobals = initTable[string, string]()
  result.recFields = initTable[string, string]()
  result.recFieldTyps = initTable[string, DataTypeKind]()
  result.lists = initTable[string, string]()
  result.slists = initTable[string, string]()
  result.llists = initTable[string, string]()
  result.rlists = initTable[string, string]()
  result.recIters = initTable[string, string]()
  result.locals = initTable[string, string]()
  result.localTyps = initTable[string, DataTypeKind]()
  result.inFunction = false
  result.curFuncName = ""
  result.curRetTyp = dtInt
  result.curRetBuf = ""
  result.curFreeStr = @[]
  result.curFreeList = @[]
  result.curFreeSList = @[]
  result.curFreeLList = @[]
  result.breakStack = @[]
  result.continueStack = @[]
  result.breakLabels = initTable[string, string]()
  result.contLabels = initTable[string, string]()
  result.curCaptured = initTable[string, string]()
  result.capturedGlobals = initTable[string, DataTypeKind]()
  result.usesBoard = false
  result.usesTecla = false
  result.usesTime = false
  result.usesAgmine = false

proc usesFirma(n: Node): bool =
  ## ¿El programa llama a Agmine.? Recorrido total, sin importar ámbito.
  if n == nil: return false
  if n.kind == nkCall and n.funcName == "Agmine": return true
  if n.thenBlock != nil and usesFirma(n.thenBlock): return true
  if n.elseBlock != nil and usesFirma(n.elseBlock): return true
  if n.cond != nil and usesFirma(n.cond): return true
  if n.left != nil and usesFirma(n.left): return true
  if n.right != nil and usesFirma(n.right): return true
  if n.target != nil and usesFirma(n.target): return true
  for a in n.args:
    if usesFirma(a): return true
  for c in n.children:
    if usesFirma(c): return true
  for f in n.fields:
    if usesFirma(f.val): return true
  return false

proc newTemp(cg: var CodeGen): string =
  result = "%t" & $cg.tempId
  inc cg.tempId

proc newLabel(cg: var CodeGen, prefix: string): string =
  result = "L" & prefix & $cg.labelId
  inc cg.labelId

proc emit(cg: var CodeGen, line: string) =
  cg.lines.add("  " & line)

proc getStrConst(cg: var CodeGen, s: string): string =
  if cg.strConsts.hasKey(s):
    return cg.strConsts[s]
  let name = "@.s" & $cg.strCounter
  inc cg.strCounter
  cg.strConsts[s] = name
  return name

proc sanitize*(s: string): string =
  ## Nombres Coma (Unicode, eñes) -> identificadores LLVM válidos [A-Za-z0-9_]
  result = ""
  for c in s:
    if c in {'A'..'Z', 'a'..'z', '0'..'9', '_'}:
      result.add(c)
    else:
      result.add("_x")
      result.add(toHex(ord(c), 2).toUpper())

proc vkCode(key: string): int =
  case key
  of "a": 65
  of "izquierda", "left", "izq", "left_arrow": 37
  of "d": 68
  of "derecha", "right", "der", "right_arrow": 39
  of "w": 87
  of "arriba", "up", "arr", "up_arrow": 38
  of "s": 83
  of "abajo", "down", "aba", "down_arrow": 40
  of "q", "salir", "quit": 81
  of "e": 69
  of "h": 72
  else:
    if key.len == 1: return ord(key[0].toUpperAscii())
    return 0

proc sysCode(key: string): int =
  ## Presets del sistema a coma_rt.h (0 = desconocido, imposible por parser).
  case key
  of "hora": 1
  of "fecha": 2
  of "usuario": 3
  of "sistema": 4
  of "version": 5
  of "directorio": 6
  else: return 0

proc padCode(key: string): int =
  ## Botones/direcciones/trastes a códigos coma_rt.h (0 = desconocido).
  case key
  of "a": 1
  of "b": 2
  of "x": 3
  of "y": 4
  of "lb": 5
  of "rb": 6
  of "atras", "back", "select", "seleccionar": 7
  of "start", "inicio", "menu": 8
  of "arriba", "up": 11
  of "abajo", "down": 12
  of "izquierda", "left": 13
  of "derecha", "right": 14
  of "verde", "green": 20
  of "roja", "rojo", "red": 21
  of "amarilla", "amarillo", "yellow": 22
  of "azul", "blue": 23
  of "naranja", "orange": 24
  of "rasgueo arriba", "strum up", "pua arriba": 25
  of "rasgueo abajo", "strum down", "pua abajo", "pua", "rasgueo", "strum": 26
  of "palanca", "whammy", "vibrato": 27
  of "inclinacion", "tilt", "estrella": 28
  else: return 0

proc symTyp(cg: CodeGen, name: string): DataTypeKind =
  let (found, sym) = cg.semaCtx.globalScope.findSym(name)
  if found: return sym.typ
  return dtUnknown

proc ensureIntGlobal(cg: var CodeGen, name: string): string =
  if cg.floatGlobals.hasKey(name): return cg.floatGlobals[name]
  if cg.strGlobals.hasKey(name): return cg.strGlobals[name]
  if cg.lists.hasKey(name): return cg.lists[name]
  if cg.slists.hasKey(name): return cg.slists[name]
  if cg.llists.hasKey(name): return cg.llists[name]
  if cg.rlists.hasKey(name): return cg.rlists[name]
  if not cg.globals.hasKey(name):
    cg.globals[name] = "@g_" & sanitize(name)
  return cg.globals[name]

proc ensureFloatGlobal(cg: var CodeGen, name: string): string =
  if not cg.floatGlobals.hasKey(name):
    cg.floatGlobals[name] = "@g_" & sanitize(name)
  return cg.floatGlobals[name]

proc ensureStrGlobal(cg: var CodeGen, name: string): string =
  if not cg.strGlobals.hasKey(name):
    cg.strGlobals[name] = "@g_" & sanitize(name)
  return cg.strGlobals[name]

proc typOfVal(ty: string): DataTypeKind =
  if ty == "i8*": dtString elif ty == "double": dtFloat else: dtInt

proc ensureRecField(cg: var CodeGen, recName, field: string,
                    hint: DataTypeKind = dtInt): string =
  let key = recName & "." & field
  if not cg.recFields.hasKey(key):
    cg.recFields[key] = "@g_" & sanitize(recName) & "_" & sanitize(field)
    cg.recFieldTyps[key] = hint
  return cg.recFields[key]

proc recFieldTyp(cg: CodeGen, recName, field: string): DataTypeKind =
  let key = recName & "." & field
  if cg.recFieldTyps.hasKey(key): return cg.recFieldTyps[key]
  return dtInt

proc ensureList(cg: var CodeGen, name: string): string =
  if not cg.lists.hasKey(name):
    cg.lists[name] = "@g_" & sanitize(name)
  return cg.lists[name]

proc ensureSList(cg: var CodeGen, name: string): string =
  if not cg.slists.hasKey(name):
    cg.slists[name] = "@g_" & sanitize(name)
  return cg.slists[name]

proc listPtr(cg: var CodeGen, n: Node): string =
  ## %CList* de una lista (local o global). "" si no es nombre.
  if n.kind != nkIdent: return ""
  if cg.inFunction and cg.locals.hasKey(n.identName):
    let lt = if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
    if lt == dtList:
      return cg.locals[n.identName]
  return cg.ensureList(n.identName)

proc listKindIsStr(cg: CodeGen, n: Node): bool =
  ## true si el nombre refiere a una lista de texto (local o global).
  if n == nil or n.kind != nkIdent: return false
  if cg.inFunction and cg.locals.hasKey(n.identName):
    let lt = if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
    return lt == dtListStr
  return cg.symTyp(n.identName) == dtListStr

proc slistPtr(cg: var CodeGen, n: Node): string =
  ## %CListStr* de una lista de texto (local o global). "" si no es nombre.
  if n.kind != nkIdent: return ""
  if cg.inFunction and cg.locals.hasKey(n.identName):
    let lt = if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
    if lt == dtListStr:
      return cg.locals[n.identName]
  return cg.ensureSList(n.identName)

proc ensureLList(cg: var CodeGen, name: string): string =
  if not cg.llists.hasKey(name):
    cg.llists[name] = "@g_" & sanitize(name)
  return cg.llists[name]

proc listKindIsList(cg: CodeGen, n: Node): bool =
  ## true si el nombre refiere a una lista de listas (local o global).
  if n == nil or n.kind != nkIdent: return false
  if cg.inFunction and cg.locals.hasKey(n.identName):
    let lt = if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
    return lt == dtListList
  return cg.symTyp(n.identName) == dtListList

proc llistPtr(cg: var CodeGen, n: Node): string =
  ## %CListList* de una lista de listas (local o global). "" si no es nombre.
  if n.kind != nkIdent: return ""
  if cg.inFunction and cg.locals.hasKey(n.identName):
    let lt = if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
    if lt == dtListList:
      return cg.locals[n.identName]
  return cg.ensureLList(n.identName)

proc ensureRList(cg: var CodeGen, name: string): string =
  if not cg.rlists.hasKey(name):
    cg.rlists[name] = "@g_" & sanitize(name)
  return cg.rlists[name]

proc rlistPtr(cg: var CodeGen, n: Node): string =
  ## %CRecList* de una lista de registros (local o global). "" si no es nombre.
  if n.kind != nkIdent: return ""
  if cg.inFunction and cg.locals.hasKey(n.identName):
    let lt = if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
    if lt == dtListRecord:
      return cg.locals[n.identName]
  return cg.ensureRList(n.identName)

proc recListKindOf(cg: CodeGen, n: Node): DataTypeKind =
  ## Clase de lista (las tres + registros) por nombre, local primero.
  if n == nil or n.kind != nkIdent: return dtUnknown
  if cg.inFunction and cg.locals.hasKey(n.identName):
    if cg.localTyps.hasKey(n.identName):
      let lt = cg.localTyps[n.identName]
      if lt in {dtList, dtListStr, dtListList, dtListRecord}: return lt
      return dtUnknown
  return cg.symTyp(n.identName)

proc recListFieldsOf(cg: CodeGen, listName: string): seq[string] =
  ## Esquema (columnas) de la lista de registros, en orden.
  let (found, sym) = cg.semaCtx.globalScope.findSym(listName)
  if found and sym.typ == dtListRecord:
    return sym.fields
  return @[]

proc recListCol(cg: CodeGen, listName, field: string): int =
  ## Columna del campo en el esquema (-1 si no existe).
  let fs = cg.recListFieldsOf(listName)
  for i, f in fs:
    if f == field: return i
  return -1

proc recSchemaOf(cg: CodeGen, lit: Node): seq[string] =
  ## Esquema (unión en orden) para construir: como sema, sin issues.
  result = @[]
  if lit == nil: return
  var rows: seq[Node] = @[]
  if lit.kind == nkListRecordLit:
    rows = lit.children
  else:
    rows = lit.children
  for row in rows:
    if row == nil: continue
    if row.kind == nkRecordLit:
      for f in row.fields:
        if f.name notin result: result.add(f.name)
    elif row.kind == nkIdent:
      let (found, sym) = cg.semaCtx.globalScope.findSym(row.identName)
      if found and sym.typ == dtRecord:
        for fn in sym.fields:
          if fn notin result: result.add(fn)

proc strLive(cg: var CodeGen, v: string): string =
  ## i8* nunca nulo para printf/strcmp/strlen ("" si llega null).
  let c = cg.newTemp()
  cg.emit(c & " = icmp eq i8* " & v & ", null")
  let e = cg.getStrConst("")
  let p = cg.newTemp()
  cg.emit(p & " = getelementptr inbounds [1 x i8], [1 x i8]* " & e & ", i32 0, i32 0")
  let r = cg.newTemp()
  cg.emit(r & " = select i1 " & c & ", i8* " & p & ", i8* " & v)
  return r

proc emitFreeLocals(cg: var CodeGen) =
  ## Libera heap de locales string/lista (params string sí; listas param no).
  for nm in cg.curFreeStr:
    if cg.locals.hasKey(nm):
      let l = cg.newTemp()
      cg.emit(l & " = load i8*, i8** " & cg.locals[nm])
      cg.emit("call void @coma_str_free(i8* " & l & ")")
  for nm in cg.curFreeList:
    if cg.locals.hasKey(nm):
      cg.emit("call void @coma_list_free(%CList* " & cg.locals[nm] & ")")
  for nm in cg.curFreeSList:
    if cg.locals.hasKey(nm):
      cg.emit("call void @coma_slist_free(%CListStr* " & cg.locals[nm] & ")")
  for nm in cg.curFreeLList:
    if cg.locals.hasKey(nm):
      cg.emit("call void @coma_llist_free(%CListList* " & cg.locals[nm] & ")")

proc emitProlog*(cg: var CodeGen) =
  cg.lines.add("; .Coma v0.7 Frontend Nim — LLVM IR portable (runtime coma/rt)")
  cg.lines.add("target triple = \"x86_64-pc-windows-msvc\"")
  cg.lines.add("")
  cg.lines.add("@.fmt_s = private unnamed_addr constant [4 x i8] c\"%s\\0A\\00\"")
  cg.lines.add("@.fmt_d = private unnamed_addr constant [4 x i8] c\"%d\\0A\\00\"")
  cg.lines.add("@.fmt_f = private unnamed_addr constant [4 x i8] c\"%g\\0A\\00\"")
  cg.lines.add("@.fmt_s0 = private unnamed_addr constant [3 x i8] c\"%s\\00\"")
  cg.lines.add("@.fmt_d0 = private unnamed_addr constant [3 x i8] c\"%d\\00\"")
  cg.lines.add("@.fmt_g0 = private unnamed_addr constant [3 x i8] c\"%g\\00\"")
  cg.lines.add("@.clearline = private unnamed_addr constant [83 x i8] c\"\\0D                                                                                \\0D\\00\"")
  cg.lines.add("@.clearscreen = private unnamed_addr constant [8 x i8] c\"\\1B[2J\\1B[H\\00\"")
  cg.lines.add("@.nl = private unnamed_addr constant [2 x i8] c\"\\0A\\00\"")
  cg.lines.add("@.cr = private unnamed_addr constant [2 x i8] c\"\\0D\\00\"")
  cg.lines.add("@.escb = private unnamed_addr constant [3 x i8] c\"\\1B\\5B\\00\"")
  cg.lines.add("@.esca = private unnamed_addr constant [2 x i8] c\"A\\00\"")
  cg.lines.add("@.mvup = private unnamed_addr constant [7 x i8] c\"\\0D\\1B\\5B%dA\\00\"")
  cg.lines.add("@.firstdraw = private global i8 1")
  cg.lines.add("@.sucia = private global i8 0")
  cg.lines.add("@.logres = private global i1 false")
  cg.lines.add("@.tecla = private global [2 x i8] zeroinitializer")
  cg.lines.add("@.tiempo = private global double 0.0")
  cg.lines.add("@.delta = private global double 0.100000e+00")
  cg.lines.add("@.bw = private global i32 10")
  cg.lines.add("@.bh = private global i32 8")
  cg.lines.add("@.cells = private global [" & $BoardCells & " x [" & $CellBytes & " x i8]] zeroinitializer")
  cg.lines.add("@.prev = private global [" & $BoardCells & " x [" & $CellBytes & " x i8]] zeroinitializer")
  cg.lines.add("@.coinx = private global i32 -1")
  cg.lines.add("@.coiny = private global i32 -1")
  cg.lines.add("@.metax = private global i32 -1")
  cg.lines.add("@.metay = private global i32 -1")
  cg.lines.add("@.prevx = private global i32 -9999")
  cg.lines.add("@.prevy = private global i32 -9999")
  cg.lines.add("@.prevtaken = private global i32 -1")
  cg.lines.add("@.dirty = private global i8 1")
  cg.lines.add("@.frame = private global [" & $FrameBytes & " x i8] zeroinitializer")
  cg.lines.add("@.fpos = private global i32 0")
  cg.lines.add("@.taby = private global i32 0")
  cg.lines.add("@.tabx = private global i32 0")
  cg.lines.add("@.e101 = private unnamed_addr constant [28 x i8] c\"E101 indice fuera de rango\\0A\\00\"")
  cg.lines.add("@.e102 = private unnamed_addr constant [24 x i8] c\"E102 division por cero\\0A\\00\"")
  cg.lines.add("@.e202l = private unnamed_addr constant [31 x i8] c\"E202 limite honesto del motor\\0A\\00\"")
  cg.lines.add("")
  cg.lines.add("; libc + runtime portable coma/rt (ver coma_rt.h)")
  cg.lines.add("declare i32 @printf(i8*, ...)")
  cg.lines.add("declare i64 @strlen(i8*)")
  cg.lines.add("declare i8* @strncpy(i8*, i8*, i64)")
  cg.lines.add("declare i32 @strcmp(i8*, i8*)")
  cg.lines.add("declare i32 @memcmp(i8*, i8*, i64)")
  cg.lines.add("declare i8* @memcpy(i8*, i8*, i64)")
  cg.lines.add("declare i8* @memset(i8*, i32, i64)")
  cg.lines.add("declare i32 @fflush(i8*)")
  cg.lines.add("declare void @exit(i32)")
  cg.lines.add("declare i32 @rand()")
  cg.lines.add("declare void @srand(i32)")
  cg.lines.add("declare i64 @time(i64*)")
  cg.lines.add("declare void @coma_console_init()")
  cg.lines.add("declare i32 @coma_kbhit()")
  cg.lines.add("declare i32 @coma_getch()")
  cg.lines.add("declare i32 @coma_key_down(i32)")
  cg.lines.add("declare void @coma_sleep_ms(i32)")
  cg.lines.add("declare void @coma_pedir(i8**)")
  cg.lines.add("declare i32 @coma_pedir_int(i32*)")
  cg.lines.add("declare void @coma_f_open(i8*)")
  cg.lines.add("declare void @coma_f_create(i8*)")
  cg.lines.add("declare void @coma_f_read(i8**)")
  cg.lines.add("declare void @coma_f_write_str(i8*)")
  cg.lines.add("declare void @coma_f_write_int(i32)")
  cg.lines.add("declare void @coma_f_write_dbl(double)")
  cg.lines.add("declare void @coma_f_close()")
  cg.lines.add("declare void @coma_f_delete(i8*)")
  cg.lines.add("declare void @coma_net_connect(i8*, i32)")
  cg.lines.add("declare void @coma_net_send_str(i8*)")
  cg.lines.add("declare void @coma_net_send_int(i32)")
  cg.lines.add("declare void @coma_net_send_dbl(double)")
  cg.lines.add("declare void @coma_net_recv(i8**)")
  cg.lines.add("declare void @coma_net_close()")
  cg.lines.add("declare i8* @coma_sys_info(i32)")
  cg.lines.add("declare i32 @coma_pedir_dbl(double*)")
  cg.lines.add("declare void @coma_tick_wait(i32)")
  cg.lines.add("declare void @coma_str_assign(i8**, i8*)")
  cg.lines.add("declare void @coma_str_free(i8*)")
  cg.lines.add("%CList = type { i32*, i32, i32 }")
  cg.lines.add("declare i32 @coma_list_len(%CList*)")
  cg.lines.add("declare i32 @coma_list_get(%CList*, i32)")
  cg.lines.add("declare void @coma_list_set(%CList*, i32, i32)")
  cg.lines.add("declare void @coma_list_add(%CList*, i32)")
  cg.lines.add("declare void @coma_list_rmval(%CList*, i32)")
  cg.lines.add("declare void @coma_list_rmat(%CList*, i32)")
  cg.lines.add("declare void @coma_list_reset(%CList*)")
  cg.lines.add("declare void @coma_list_copy(%CList*, %CList*)")
  cg.lines.add("declare void @coma_list_free(%CList*)")
  cg.lines.add("%CListStr = type { i8**, i32, i32 }")
  cg.lines.add("declare i32 @coma_slist_len(%CListStr*)")
  cg.lines.add("declare i8* @coma_slist_get(%CListStr*, i32)")
  cg.lines.add("declare void @coma_slist_set(%CListStr*, i32, i8*)")
  cg.lines.add("declare void @coma_slist_add(%CListStr*, i8*)")
  cg.lines.add("declare void @coma_slist_rmval(%CListStr*, i8*)")
  cg.lines.add("declare void @coma_slist_rmat(%CListStr*, i32)")
  cg.lines.add("declare void @coma_slist_reset(%CListStr*)")
  cg.lines.add("declare void @coma_slist_copy(%CListStr*, %CListStr*)")
  cg.lines.add("declare void @coma_slist_free(%CListStr*)")
  cg.lines.add("%CListList = type { %CList*, i32, i32 }")
  cg.lines.add("declare i32 @coma_llist_len(%CListList*)")
  cg.lines.add("declare void @coma_llist_get(%CListList*, i32, %CList*)")
  cg.lines.add("declare void @coma_llist_set(%CListList*, i32, %CList*)")
  cg.lines.add("declare void @coma_llist_add(%CListList*, %CList*)")
  cg.lines.add("declare void @coma_llist_rmval(%CListList*, %CList*)")
  cg.lines.add("declare void @coma_llist_rmat(%CListList*, i32)")
  cg.lines.add("declare void @coma_llist_reset(%CListList*)")
  cg.lines.add("declare void @coma_llist_copy(%CListList*, %CListList*)")
  cg.lines.add("declare void @coma_llist_free(%CListList*)")
  cg.lines.add("%CRecList = type { i32*, i32, i32 }")
  cg.lines.add("declare void @coma_rlist_reset(%CRecList*, i32)")
  cg.lines.add("declare void @coma_rlist_addrow(%CRecList*)")
  cg.lines.add("declare i32 @coma_rlist_len(%CRecList*)")
  cg.lines.add("declare i32 @coma_rlist_get(%CRecList*, i32, i32)")
  cg.lines.add("declare void @coma_rlist_set(%CRecList*, i32, i32, i32)")
  cg.lines.add("declare void @coma_rlist_copy(%CRecList*, %CRecList*)")
  cg.lines.add("declare void @coma_rlist_free(%CRecList*)")
  cg.lines.add("declare i32 @coma_pad_count()")
  cg.lines.add("declare i32 @coma_pad_down(i32, i32)")
  cg.lines.add("declare i8* @coma_pad_last(i32)")
  cg.lines.add("declare i32 @coma_stricmp(i8*, i8*)")
  # Firma propia: Agmine. imprime la firma y devuelve 0.
  # Solo se emite si se usa (cero coste en el resto).
  if cg.usesAgmine:
    cg.lines.add("@.firma = private unnamed_addr constant [19 x i8] c\"creado por Agmine\\0A\\00\"")
    cg.lines.add("define i32 @Agmine() {")
    cg.lines.add("  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([19 x i8], [19 x i8]* @.firma, i32 0, i32 0))")
    cg.lines.add("  call i32 @fflush(i8* null)")
    cg.lines.add("  ret i32 0")
    cg.lines.add("}")
  cg.lines.add("")

proc genExpr*(cg: var CodeGen, n: Node): (string, string)
proc genStmt*(cg: var CodeGen, n: Node)

proc toI32(cg: var CodeGen, v, ty: string): string =
  ## Total: cualquier tipo acaba en i32 válido (punteros -> 0, nunca IR roto).
  if ty == "i32": return v
  if ty == "i8*" or ty == "%CList*": return "0"
  let t = cg.newTemp()
  if ty == "i1":
    cg.emit(t & " = zext i1 " & v & " to i32")
  elif ty == "i8" or ty == "i16":
    cg.emit(t & " = sext " & ty & " " & v & " to i32")
  elif ty == "i64":
    cg.emit(t & " = trunc i64 " & v & " to i32")
  elif ty == "double":
    cg.emit(t & " = fptosi double " & v & " to i32")
  else:
    return v
  return t

proc toI1(cg: var CodeGen, v, ty: string): string =
  if ty == "i1": return v
  let t = cg.newTemp()
  if ty == "double":
    cg.emit(t & " = fcmp one double " & v & ", 0.0")
  elif ty == "i8*":
    let l = cg.newTemp()
    cg.emit(l & " = call i64 @strlen(i8* " & v & ")")
    cg.emit(t & " = icmp ne i64 " & l & ", 0")
  else:
    cg.emit(t & " = icmp ne i32 " & cg.toI32(v, ty) & ", 0")
  return t

proc toDouble(cg: var CodeGen, v, ty: string): string =
  ## Total: cualquier tipo acaba en double válido (punteros -> 0.0).
  if ty == "double": return v
  if ty == "i8*" or ty == "%CList*": return "0.0"
  let t = cg.newTemp()
  if ty == "i1":
    cg.emit(t & " = uitofp i1 " & v & " to double")
  else:
    cg.emit(t & " = sitofp " & ty & " " & v & " to double")
  return t

proc framePut(cg: var CodeGen, frameA, posA, srcPtr, lenV: string) =
  ## Añade lenV bytes al frame (1 printf gordo al final, no 90 finos).
  let pv = cg.newTemp()
  cg.emit(pv & " = load i32, i32* " & posA)
  let dst = cg.newTemp()
  cg.emit(dst & " = getelementptr inbounds [" & $FrameBytes & " x i8], [" & $FrameBytes & " x i8]* " & frameA & ", i32 0, i32 " & pv)
  let ln64 = cg.newTemp()
  cg.emit(ln64 & " = zext i32 " & lenV & " to i64")
  cg.emit("call i8* @memcpy(i8* " & dst & ", i8* " & srcPtr & ", i64 " & ln64 & ")")
  let np = cg.newTemp()
  cg.emit(np & " = add i32 " & pv & ", " & lenV)
  cg.emit("store i32 " & np & ", i32* " & posA)

proc frameByte(cg: var CodeGen, frameA, posA: string, b: int) =
  let pv = cg.newTemp()
  cg.emit(pv & " = load i32, i32* " & posA)
  let dst = cg.newTemp()
  cg.emit(dst & " = getelementptr inbounds [" & $FrameBytes & " x i8], [" & $FrameBytes & " x i8]* " & frameA & ", i32 0, i32 " & pv)
  cg.emit("store i8 " & $b & ", i8* " & dst)
  let np = cg.newTemp()
  cg.emit(np & " = add i32 " & pv & ", 1")
  cg.emit("store i32 " & np & ", i32* " & posA)

proc emitKeyPoll(cg: var CodeGen) =
  ## Muestreo no bloqueante a @.tecla. El runtime ya devuelve minúscula
  ## con flechas mapeadas a wasd: aquí solo guardar.
  let kb = cg.newTemp()
  cg.emit(kb & " = call i32 @coma_kbhit()")
  let kc = cg.newTemp()
  cg.emit(kc & " = icmp ne i32 " & kb & ", 0")
  let hitL = cg.newLabel("khit")
  let contL = cg.newLabel("kcont")
  cg.emit("br i1 " & kc & ", label %" & hitL & ", label %" & contL)
  cg.lines.add(hitL & ":")
  let ch = cg.newTemp()
  cg.emit(ch & " = call i32 @coma_getch()")
  let by = cg.newTemp()
  cg.emit(by & " = trunc i32 " & ch & " to i8")
  let pt = cg.newTemp()
  cg.emit(pt & " = getelementptr inbounds [2 x i8], [2 x i8]* @.tecla, i32 0, i32 0")
  cg.emit("store i8 " & by & ", i8* " & pt)
  let pt1 = cg.newTemp()
  cg.emit(pt1 & " = getelementptr inbounds [2 x i8], [2 x i8]* @.tecla, i32 0, i32 1")
  cg.emit("store i8 0, i8* " & pt1)
  cg.emit("br label %" & contL)
  cg.lines.add(contL & ":")

proc genLogicAndOr(cg: var CodeGen, n: Node, isAnd: bool): (string, string) =
  ## y/o CON cortocircuito: la derecha solo se genera en su propia rama.
  ## (Si se generase arriba con el resto, un E101 de la derecha abortaría
  ## aunque la izquierda ya decidiese. Bug real, aquí muerto.)
  ## OJO: la derecha puede traer sus propios branches (E101, azar, lee...),
  ## así que el resultado viaja por slot global @.logres, no por PHI
  ## (el PHI exigiría saber en qué bloque terminó la derecha).
  let (vL, tyL) = cg.genExpr(n.left)
  let bl = cg.toI1(vL, tyL)
  let evalL = cg.newLabel(if isAnd: "y" else: "o")
  let shortL = cg.newLabel("atajo")
  let endL = cg.newLabel("finlog")
  if isAnd:
    cg.emit("br i1 " & bl & ", label %" & evalL & ", label %" & shortL)
  else:
    cg.emit("br i1 " & bl & ", label %" & shortL & ", label %" & evalL)
  cg.lines.add(evalL & ":")
  let (vR, tyR) = cg.genExpr(n.right)
  let br2 = cg.toI1(vR, tyR)
  cg.emit("store i1 " & br2 & ", i1* @.logres")
  cg.emit("br label %" & endL)
  cg.lines.add(shortL & ":")
  let shortVal = if isAnd: "false" else: "true"
  cg.emit("store i1 " & shortVal & ", i1* @.logres")
  cg.emit("br label %" & endL)
  cg.lines.add(endL & ":")
  let res = cg.newTemp()
  cg.emit(res & " = load i1, i1* @.logres")
  return (res, "i1")

proc exprIsFloat(cg: CodeGen, n: Node): bool =
  ## ¿La expresión vale double? (para inferir el tipo de una local)
  if n == nil: return false
  case n.kind
  of nkFloat: return true
  of nkDelta, nkTiempo: return true
  of nkBinaryOp:
    if n.strVal == "entre": return true
    return cg.exprIsFloat(n.left) or cg.exprIsFloat(n.right)
  of nkUnaryOp:
    if n.strVal == "menos": return cg.exprIsFloat(n.left)
    return false
  of nkIdent:
    return cg.symTyp(n.identName) == dtFloat
  else: return false

proc collectBodyLocals(cg: var CodeGen, body: Node, types: var Table[string, DataTypeKind]) =
  ## Nombres asignados en el cuerpo (recursivo): seran alloca, no globals.
  ## dtUnknown = lista/registro (siguen en global: limite honesto v1).
  ## pedir no se recoge: por spec crea global.
  if body == nil: return
  case body.kind
  of nkAssign:
    # Las capturadas de closure ya son globales: no alloca local.
    if cg.capturedGlobals.hasKey(body.identName):
      collectBodyLocals(cg, body.left, types)
      return
    if not types.hasKey(body.identName):
      if body.left != nil and body.left.kind == nkStr:
        types[body.identName] = dtString
      elif body.left != nil and body.left.kind == nkIdent:
        # Copia entre listas (`H igual G.`): hereda la clase, salvo
        # registros (entidades globales, spec 12: nunca locales).
        var ct = dtUnknown
        if types.hasKey(body.left.identName): ct = types[body.left.identName]
        elif cg.localTyps.hasKey(body.left.identName): ct = cg.localTyps[body.left.identName]
        else:
          let (cfound, csym) = cg.semaCtx.globalScope.findSym(body.left.identName)
          if cfound: ct = csym.typ
        if ct in {dtList, dtListStr, dtListList}:
          types[body.identName] = ct
      elif body.left != nil and body.left.kind == nkListLit:
        # Misma inferencia que sema: todo texto -> texto, todo filas -> anidada,
        # todo registros -> GLOBAL (como las entidades, spec 12).
        var todoTexto = body.left.children.len > 0
        var todoFilas = body.left.children.len > 0
        var todoRecs = body.left.children.len > 0
        for ch in body.left.children:
          if ch.kind == nkStr:
            todoFilas = false
            todoRecs = false
            continue
          elif ch.kind == nkRecordLit:
            todoTexto = false
            todoFilas = false
            continue
          elif ch.kind == nkIdent:
            var ct = dtUnknown
            if types.hasKey(ch.identName): ct = types[ch.identName]
            elif cg.localTyps.hasKey(ch.identName): ct = cg.localTyps[ch.identName]
            else:
              let (cfound, csym) = cg.semaCtx.globalScope.findSym(ch.identName)
              if cfound: ct = csym.typ
            if ct != dtString: todoTexto = false
            if ct != dtList: todoFilas = false
            if ct != dtRecord: todoRecs = false
            if not todoTexto and not todoFilas and not todoRecs: break
          else:
            todoTexto = false
            todoFilas = false
            todoRecs = false
            break
        if todoRecs:
          discard # registros-lista: global compartido, no local
        elif todoTexto:
          types[body.identName] = dtListStr
        elif todoFilas:
          types[body.identName] = dtListList
        else:
          types[body.identName] = dtList
      elif body.left != nil and body.left.kind == nkRecordLit:
        types[body.identName] = dtUnknown # registros: global (límite honesto)
      elif body.left != nil and body.left.kind == nkListRecordLit:
        discard # listas de registros: global compartido, no local
      elif body.left != nil and body.left.kind == nkCall:
        let (cf, cs) = cg.semaCtx.globalScope.findSym(body.left.funcName)
        if cf and cs.kind == skFunc and cs.typ in {dtInt, dtFloat, dtString, dtList, dtListStr, dtListList}:
          types[body.identName] = cs.typ
        else:
          types[body.identName] = dtInt
      elif body.left != nil and cg.exprIsFloat(body.left):
        types[body.identName] = dtFloat
      else:
        types[body.identName] = dtInt
  of nkForEach:
    if not types.hasKey(body.identName):
      var itKind = dtInt
      if body.left != nil and body.left.kind == nkIdent:
        var lt = dtUnknown
        if types.hasKey(body.left.identName): lt = types[body.left.identName]
        elif cg.localTyps.hasKey(body.left.identName): lt = cg.localTyps[body.left.identName]
        else:
          let (lfound, lsym) = cg.semaCtx.globalScope.findSym(body.left.identName)
          if lfound: lt = lsym.typ
        if lt == dtListStr: itKind = dtString
        elif lt == dtListList: itKind = dtList
      types[body.identName] = itKind
    cg.collectBodyLocals(body.thenBlock, types)
  of nkBlock:
    for s in body.children: cg.collectBodyLocals(s, types)
  of nkIf:
    cg.collectBodyLocals(body.thenBlock, types)
    if body.elseBlock != nil and body.elseBlock.kind in {nkBlock, nkIf}:
      cg.collectBodyLocals(body.elseBlock, types)
  of nkWhile, nkTick:
    cg.collectBodyLocals(body.thenBlock, types)
  of nkMatch:
    for br in body.children: cg.collectBodyLocals(br.thenBlock, types)
    if body.elseBlock != nil: cg.collectBodyLocals(body.elseBlock, types)
  else: discard

proc genExpr*(cg: var CodeGen, n: Node): (string, string) =
  if n == nil: return ("0", "i32")

  case n.kind
  of nkInt:
    let ty = "i" & $max(8, n.intWidth)
    return ($n.intVal, ty)

  of nkFloat:
    return ($n.floatVal, "double")

  of nkBool:
    let b = if n.intVal != 0: "true" else: "false"
    return (b, "i1")

  of nkStr:
    let constName = cg.getStrConst(n.strVal)
    let len = n.strVal.len + 1
    let t = cg.newTemp()
    cg.emit(t & " = getelementptr inbounds [" & $len & " x i8], [" & $len & " x i8]* " & constName & ", i32 0, i32 0")
    return (t, "i8*")

  of nkIdent:
    # Variable capturada por closure: se elevó a global, leer de ella.
    if cg.curCaptured.hasKey(n.identName):
      let g = cg.curCaptured[n.identName]
      let lt = cg.capturedGlobals[n.identName]
      if lt == dtString:
        let t = cg.newTemp()
        cg.emit(t & " = load i8*, i8** " & g)
        return (cg.strLive(t), "i8*")
      elif lt == dtFloat:
        let t = cg.newTemp()
        cg.emit(t & " = load double, double* " & g)
        return (t, "double")
      else:
        let t = cg.newTemp()
        cg.emit(t & " = load i32, i32* " & g)
        return (t, "i32")
    if cg.inFunction and cg.locals.hasKey(n.identName):
      let lt = if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
      if lt == dtString:
        let t = cg.newTemp()
        cg.emit(t & " = load i8*, i8** " & cg.locals[n.identName])
        return (cg.strLive(t), "i8*")
      elif lt == dtFloat:
        let t = cg.newTemp()
        cg.emit(t & " = load double, double* " & cg.locals[n.identName])
        return (t, "double")
      elif lt == dtList:
        return (cg.locals[n.identName], "%CList*")
      elif lt == dtListStr:
        return (cg.locals[n.identName], "%CListStr*")
      elif lt == dtListList:
        return (cg.locals[n.identName], "%CListList*")
      elif lt == dtListRecord:
        return (cg.locals[n.identName], "%CRecList*")
      let t = cg.newTemp()
      cg.emit(t & " = load i32, i32* " & cg.locals[n.identName])
      return (t, "i32")
    let typ = cg.symTyp(n.identName)
    if typ == dtString:
      let g = cg.ensureStrGlobal(n.identName)
      let t = cg.newTemp()
      cg.emit(t & " = load i8*, i8** " & g)
      return (cg.strLive(t), "i8*")
    elif typ == dtList:
      return (cg.ensureList(n.identName), "%CList*")
    elif typ == dtListStr:
      return (cg.ensureSList(n.identName), "%CListStr*")
    elif typ == dtListList:
      return (cg.ensureLList(n.identName), "%CListList*")
    elif typ == dtListRecord:
      return (cg.ensureRList(n.identName), "%CRecList*")
    elif typ == dtListRecord:
      return (cg.ensureRList(n.identName), "%CRecList*")
    elif typ == dtFloat:
      let g = cg.ensureFloatGlobal(n.identName)
      let t = cg.newTemp()
      cg.emit(t & " = load double, double* " & g)
      return (t, "double")
    else:
      let g = cg.ensureIntGlobal(n.identName)
      let t = cg.newTemp()
      cg.emit(t & " = load i32, i32* " & g)
      return (t, "i32")

  of nkTecla:
    cg.usesTecla = true
    if n.strVal.len > 0:
      # Sondeo directo (runtime portable) -> i1
      let code = vkCode(n.strVal)
      if code == 0:
        # clave desconocida: comparar buffer (texto)
        let t = cg.newTemp()
        cg.emit(t & " = getelementptr inbounds [2 x i8], [2 x i8]* @.tecla, i32 0, i32 0")
        return (t, "i8*")
      let st = cg.newTemp()
      cg.emit(st & " = call i32 @coma_key_down(i32 " & $code & ")")
      let r = cg.newTemp()
      cg.emit(r & " = icmp ne i32 " & st & ", 0")
      return (r, "i1")
    # Tecla sola: muestreo no bloqueante AQUÍ MISMO (vale en mientras, en_caso,
    # segun... no solo en tick). Si hay tecla, al buffer; si no, queda la última.
    cg.emitKeyPoll()
    let t = cg.newTemp()
    cg.emit(t & " = getelementptr inbounds [2 x i8], [2 x i8]* @.tecla, i32 0, i32 0")
    return (t, "i8*")

  of nkMando:
    # Mando "verde" = botón apretado AHORA (i1); Mando solo = último botón (texto).
    if n.strVal.len > 0:
      let code = padCode(n.strVal)
      if code == 0:
        let t = cg.newTemp()
        cg.emit(t & " = call i8* @coma_pad_last(i32 0)")
        return (t, "i8*")
      let st = cg.newTemp()
      cg.emit(st & " = call i32 @coma_pad_down(i32 0, i32 " & $code & ")")
      let r = cg.newTemp()
      cg.emit(r & " = icmp ne i32 " & st & ", 0")
      return (r, "i1")
    let t = cg.newTemp()
    cg.emit(t & " = call i8* @coma_pad_last(i32 0)")
    return (t, "i8*")

  of nkSistema:
    let t = cg.newTemp()
    cg.emit(t & " = call i8* @coma_sys_info(i32 " & $sysCode(n.strVal) & ")")
    return (t, "i8*")

  of nkDelta:
    cg.usesTime = true
    let t = cg.newTemp()
    cg.emit(t & " = load double, double* @.delta")
    return (t, "double")

  of nkTiempo:
    cg.usesTime = true
    let t = cg.newTemp()
    cg.emit(t & " = load double, double* @.tiempo")
    return (t, "double")

  of nkAzar:
    let (maxVal, maxTy) = cg.genExpr(n.left)
    let mi = cg.toI32(maxVal, maxTy)
    let okL = cg.newLabel("azarok")
    let badL = cg.newLabel("azaruno")
    let endL = cg.newLabel("azarfin")
    let c = cg.newTemp()
    cg.emit(c & " = icmp sgt i32 " & mi & ", 0")
    cg.emit("br i1 " & c & ", label %" & okL & ", label %" & badL)
    cg.lines.add(okL & ":")
    let trand = cg.newTemp()
    cg.emit(trand & " = call i32 @rand()")
    let trem = cg.newTemp()
    cg.emit(trem & " = srem i32 " & trand & ", " & mi)
    let tres = cg.newTemp()
    cg.emit(tres & " = add i32 " & trem & ", 1")
    cg.emit("br label %" & endL)
    cg.lines.add(badL & ":")
    cg.emit("br label %" & endL)
    cg.lines.add(endL & ":")
    let phi = cg.newTemp()
    cg.emit(phi & " = phi i32 [ " & tres & ", %" & okL & " ], [ 1, %" & badL & " ]")
    return (phi, "i32")

  of nkLeeCasilla:
    cg.usesBoard = true
    let (xv, xt) = cg.genExpr(n.left)
    let (yv, yt) = cg.genExpr(n.right)
    let xi = cg.toI32(xv, xt)
    let yi = cg.toI32(yv, yt)
    let w = cg.newTemp()
    cg.emit(w & " = load i32, i32* @.bw")
    let h = cg.newTemp()
    cg.emit(h & " = load i32, i32* @.bh")
    let okx1 = cg.newTemp()
    cg.emit(okx1 & " = icmp sge i32 " & xi & ", 0")
    let okx2 = cg.newTemp()
    cg.emit(okx2 & " = icmp slt i32 " & xi & ", " & w)
    let oky1 = cg.newTemp()
    cg.emit(oky1 & " = icmp sge i32 " & yi & ", 0")
    let oky2 = cg.newTemp()
    cg.emit(oky2 & " = icmp slt i32 " & yi & ", " & h)
    let ok1 = cg.newTemp()
    cg.emit(ok1 & " = and i1 " & okx1 & ", " & okx2)
    let ok2 = cg.newTemp()
    cg.emit(ok2 & " = and i1 " & oky1 & ", " & oky2)
    let ok = cg.newTemp()
    cg.emit(ok & " = and i1 " & ok1 & ", " & ok2)
    let goodL = cg.newLabel("leeok")
    let badL = cg.newLabel("leebad")
    let endL = cg.newLabel("leefin")
    cg.emit("br i1 " & ok & ", label %" & goodL & ", label %" & badL)
    cg.lines.add(goodL & ":")
    let idx1 = cg.newTemp()
    cg.emit(idx1 & " = mul i32 " & yi & ", " & $BoardMax)
    let idx2 = cg.newTemp()
    cg.emit(idx2 & " = add i32 " & idx1 & ", " & xi)
    let cellp = cg.newTemp()
    cg.emit(cellp & " = getelementptr inbounds [" & $BoardCells & " x [" & $CellBytes & " x i8]], [" & $BoardCells & " x [" & $CellBytes & " x i8]]* @.cells, i32 0, i32 " & idx2 & ", i32 0")
    cg.emit("br label %" & endL)
    cg.lines.add(badL & ":")
    let emptyC = cg.getStrConst("")
    let eLen = 1
    let emptyp = cg.newTemp()
    cg.emit(emptyp & " = getelementptr inbounds [" & $eLen & " x i8], [" & $eLen & " x i8]* " & emptyC & ", i32 0, i32 0")
    cg.emit("br label %" & endL)
    cg.lines.add(endL & ":")
    let phi = cg.newTemp()
    cg.emit(phi & " = phi i8* [ " & cellp & ", %" & goodL & " ], [ " & emptyp & ", %" & badL & " ]")
    return (phi, "i8*")

  of nkBinaryOp:
    if n.strVal == "y":
      return cg.genLogicAndOr(n, true)
    if n.strVal == "o":
      return cg.genLogicAndOr(n, false)
    let (vL, tyL) = cg.genExpr(n.left)
    let (vR, tyR) = cg.genExpr(n.right)
    if n.strVal == "es_equivalente_a":
      if tyL != "i8*" or tyR != "i8*":
        return ("false", "i1")
      let c = cg.newTemp()
      cg.emit(c & " = call i32 @coma_stricmp(i8* " & vL & ", i8* " & vR & ")")
      let r = cg.newTemp()
      cg.emit(r & " = icmp eq i32 " & c & ", 0")
      return (r, "i1")

    # Comparaciones de texto via strcmp
    if n.strVal in ["es_igual_a", "igual", "es_distinto_de"] and (tyL == "i8*" or tyR == "i8*"):
      if tyL != "i8*" or tyR != "i8*":
        # texto vs numero: nunca iguales (distinto=true)
        if n.strVal == "es_distinto_de": return ("true", "i1")
        return ("false", "i1")
      let c = cg.newTemp()
      cg.emit(c & " = call i32 @strcmp(i8* " & vL & ", i8* " & vR & ")")
      let r = cg.newTemp()
      if n.strVal == "es_distinto_de":
        cg.emit(r & " = icmp ne i32 " & c & ", 0")
      else:
        cg.emit(r & " = icmp eq i32 " & c & ", 0")
      return (r, "i1")
    # Resto de comparaciones texto vs texto con <,>,<=,>=: usar strcmp
    if tyL == "i8*" and tyR == "i8*" and n.strVal in ["es_mayor_que", "es_menor_que", "es_mayor_o_igual", "es_menor_o_igual"]:
      let c = cg.newTemp()
      cg.emit(c & " = call i32 @strcmp(i8* " & vL & ", i8* " & vR & ")")
      let r = cg.newTemp()
      case n.strVal
      of "es_mayor_que": cg.emit(r & " = icmp sgt i32 " & c & ", 0")
      of "es_menor_que": cg.emit(r & " = icmp slt i32 " & c & ", 0")
      of "es_mayor_o_igual": cg.emit(r & " = icmp sge i32 " & c & ", 0")
      else: cg.emit(r & " = icmp sle i32 " & c & ", 0")
      return (r, "i1")
    let isFloat = tyL == "double" or tyR == "double" or n.strVal == "entre"
    if isFloat and n.strVal in ["mas", "menos", "por", "entre"]:
      let l = cg.toDouble(vL, tyL)
      let r = cg.toDouble(vR, tyR)
      # E102: divisor cero en float
      if n.strVal == "entre":
        let z = cg.newTemp()
        cg.emit(z & " = fcmp oeq double " & r & ", 0.0")
        let okL = cg.newLabel("divok")
        let badL = cg.newLabel("divcero")
        cg.emit("br i1 " & z & ", label %" & badL & ", label %" & okL)
        cg.lines.add(badL & ":")
        cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([23 x i8], [23 x i8]* @.e102, i32 0, i32 0))")
        cg.emit("call void @exit(i32 1)")
        cg.emit("unreachable")
        cg.lines.add(okL & ":")
      let res = cg.newTemp()
      case n.strVal
      of "mas": cg.emit(res & " = fadd double " & l & ", " & r)
      of "menos": cg.emit(res & " = fsub double " & l & ", " & r)
      of "por": cg.emit(res & " = fmul double " & l & ", " & r)
      else: cg.emit(res & " = fdiv double " & l & ", " & r)
      return (res, "double")
    if isFloat:
      let l = cg.toDouble(vL, tyL)
      let r = cg.toDouble(vR, tyR)
      let res = cg.newTemp()
      case n.strVal
      of "es_igual_a", "igual": cg.emit(res & " = fcmp oeq double " & l & ", " & r)
      of "es_mayor_que": cg.emit(res & " = fcmp ogt double " & l & ", " & r)
      of "es_menor_que": cg.emit(res & " = fcmp olt double " & l & ", " & r)
      of "es_distinto_de": cg.emit(res & " = fcmp one double " & l & ", " & r)
      of "es_mayor_o_igual": cg.emit(res & " = fcmp oge double " & l & ", " & r)
      of "es_menor_o_igual": cg.emit(res & " = fcmp ole double " & l & ", " & r)
      else: return ("false", "i1")
      return (res, "i1")
    # Ruta entera
    let l = cg.toI32(vL, tyL)
    let r = cg.toI32(vR, tyR)
    let res = cg.newTemp()
    case n.strVal
    of "mas":
      cg.emit(res & " = add i32 " & l & ", " & r)
      return (res, "i32")
    of "menos":
      cg.emit(res & " = sub i32 " & l & ", " & r)
      return (res, "i32")
    of "por":
      cg.emit(res & " = mul i32 " & l & ", " & r)
      return (res, "i32")
    of "y_bit":
      cg.emit(res & " = and i32 " & l & ", " & r)
      return (res, "i32")
    of "o_bit":
      cg.emit(res & " = or i32 " & l & ", " & r)
      return (res, "i32")
    of "xor":
      cg.emit(res & " = xor i32 " & l & ", " & r)
      return (res, "i32")
    of "desplaza_izquierda":
      cg.emit(res & " = shl i32 " & l & ", " & r)
      return (res, "i32")
    of "desplaza_derecha":
      cg.emit(res & " = ashr i32 " & l & ", " & r)
      return (res, "i32")
    of "entre":
      # no debería llegar (entre siempre va por float), pero por seguridad
      cg.emit(res & " = sdiv i32 " & l & ", " & r)
      return (res, "i32")
    of "es_igual_a", "igual":
      cg.emit(res & " = icmp eq i32 " & l & ", " & r)
      return (res, "i1")
    of "es_mayor_que":
      cg.emit(res & " = icmp sgt i32 " & l & ", " & r)
      return (res, "i1")
    of "es_menor_que":
      cg.emit(res & " = icmp slt i32 " & l & ", " & r)
      return (res, "i1")
    of "es_distinto_de":
      cg.emit(res & " = icmp ne i32 " & l & ", " & r)
      return (res, "i1")
    of "es_mayor_o_igual":
      cg.emit(res & " = icmp sge i32 " & l & ", " & r)
      return (res, "i1")
    of "es_menor_o_igual":
      cg.emit(res & " = icmp sle i32 " & l & ", " & r)
      return (res, "i1")
    else:
      return ("0", "i32")

  of nkUnaryOp:
    let (v, ty) = cg.genExpr(n.left)
    if n.strVal == "no":
      let b = cg.toI1(v, ty)
      let res = cg.newTemp()
      cg.emit(res & " = xor i1 " & b & ", true")
      return (res, "i1")
    elif n.strVal == "menos":
      if ty == "double":
        let res = cg.newTemp()
        cg.emit(res & " = fneg double " & v)
        return (res, "double")
      let res = cg.newTemp()
      cg.emit(res & " = sub i32 0, " & cg.toI32(v, ty))
      return (res, "i32")
    return (v, ty)

  of nkCall:
    # Firma de la callee: convierte cada arg a su tipo (sema ya valido).
    var ptyps: seq[DataTypeKind] = @[]
    let (cfound, cfsym) = cg.semaCtx.globalScope.findSym(n.funcName)
    if cfound and cfsym.kind == skFunc:
      ptyps = cfsym.paramTyps
    var argList = ""
    for i, a in n.args:
      let (v, ty) = cg.genExpr(a)
      let want = if i < ptyps.len: ptyps[i] else: dtInt
      if i > 0: argList.add(", ")
      if want == dtString:
        if ty == "i8*":
          argList.add("i8* " & v)
        else:
          # sema ya aborto; defensivo para no romper el IR
          let e = cg.getStrConst("")
          argList.add("i8* getelementptr inbounds ([1 x i8], [1 x i8]* " & e & ", i32 0, i32 0)")
      elif want == dtFloat:
        argList.add("double " & cg.toDouble(v, ty))
      elif want == dtList:
        if ty == "%CList*":
          argList.add("%CList* " & v)
        elif ty == "%CList":
          let tmp = cg.newTemp()
          cg.emit(tmp & " = alloca %CList")
          cg.emit("store %CList " & v & ", %CList* " & tmp)
          argList.add("%CList* " & tmp)
        else:
          argList.add("%CList* null")
      elif want == dtListStr:
        if ty == "%CListStr*":
          argList.add("%CListStr* " & v)
        elif ty == "%CListStr":
          let tmp = cg.newTemp()
          cg.emit(tmp & " = alloca %CListStr")
          cg.emit("store %CListStr " & v & ", %CListStr* " & tmp)
          argList.add("%CListStr* " & tmp)
        else:
          argList.add("%CListStr* null")
      elif want == dtListList:
        if ty == "%CListList*":
          argList.add("%CListList* " & v)
        elif ty == "%CListList":
          let tmp = cg.newTemp()
          cg.emit(tmp & " = alloca %CListList")
          cg.emit("store %CListList " & v & ", %CListList* " & tmp)
          argList.add("%CListList* " & tmp)
        else:
          argList.add("%CListList* null")
      else:
        argList.add("i32 " & cg.toI32(v, ty))
    let retTy = if cfound and cfsym.kind == skFunc: cfsym.typ else: dtInt
    let res = cg.newTemp()
    if retTy == dtString:
      cg.emit(res & " = call i8* @" & sanitize(n.funcName) & "(" & argList & ")")
      return (res, "i8*")
    elif retTy == dtFloat:
      cg.emit(res & " = call double @" & sanitize(n.funcName) & "(" & argList & ")")
      return (res, "double")
    elif retTy == dtList:
      cg.emit(res & " = call %CList @" & sanitize(n.funcName) & "(" & argList & ")")
      return (res, "%CList")
    elif retTy == dtListStr:
      cg.emit(res & " = call %CListStr @" & sanitize(n.funcName) & "(" & argList & ")")
      return (res, "%CListStr")
    elif retTy == dtListList:
      cg.emit(res & " = call %CListList @" & sanitize(n.funcName) & "(" & argList & ")")
      return (res, "%CListList")
    else:
      cg.emit(res & " = call i32 @" & sanitize(n.funcName) & "(" & argList & ")")
      return (res, "i32")

  of nkFieldAccess:
    # Campo de lista de registros: `Vida de E` (E = posición) o
    # `Vida de elemento 2 de G`. La columna se resuelve compilando.
    if n.left != nil and n.left.kind == nkIdent and cg.recIters.hasKey(n.left.identName):
      let lst = cg.recIters[n.left.identName]
      let col = cg.recListCol(lst, n.strVal)
      if col >= 0:
        let lp = cg.rlistPtr(Node(kind: nkIdent, identName: lst))
        var rowV = ""
        if cg.inFunction and cg.locals.hasKey(n.left.identName):
          let t = cg.newTemp()
          cg.emit(t & " = load i32, i32* " & cg.locals[n.left.identName])
          rowV = t
        else:
          let g = cg.ensureIntGlobal(n.left.identName)
          let t = cg.newTemp()
          cg.emit(t & " = load i32, i32* " & g)
          rowV = t
        let r0 = cg.newTemp()
        cg.emit(r0 & " = sub i32 " & rowV & ", 1")
        let v = cg.newTemp()
        cg.emit(v & " = call i32 @coma_rlist_get(%CRecList* " & lp & ", i32 " & r0 & ", i32 " & $col & ")")
        return (v, "i32")
    if n.left != nil and n.left.kind == nkListAccess:
      let inner = n.left.left
      if inner != nil and inner.kind == nkIdent:
        let (lfound, lsym) = cg.semaCtx.globalScope.findSym(inner.identName)
        if lfound and lsym.typ == dtListRecord:
          var col = -1
          for i, f in lsym.fields:
            if f == n.strVal: col = i
          if col >= 0:
            let lp = cg.rlistPtr(inner)
            let (iv, it) = cg.genExpr(n.left.right)
            var r0 = ""
            if n.left.strVal == "primero":
              r0 = "0"
            elif n.left.strVal == "ultimo":
              let ln = cg.newTemp()
              cg.emit(ln & " = call i32 @coma_rlist_len(%CRecList* " & lp & ")")
              let t = cg.newTemp()
              cg.emit(t & " = sub i32 " & ln & ", 1")
              r0 = t
            else:
              r0 = cg.newTemp()
              cg.emit(r0 & " = sub i32 " & cg.toI32(iv, it) & ", 1")
            let v = cg.newTemp()
            cg.emit(v & " = call i32 @coma_rlist_get(%CRecList* " & lp & ", i32 " & r0 & ", i32 " & $col & ")")
            return (v, "i32")
    # Campo de registro tipado (primera escritura manda; por defecto entero).
    var recName = ""
    if n.left.kind == nkIdent:
      recName = n.left.identName
    else:
      let (rv, _) = cg.genExpr(n.left)
      discard rv
      recName = "?"
    let ft = cg.recFieldTyp(recName, n.strVal)
    let g = cg.ensureRecField(recName, n.strVal, ft)
    if ft == dtString:
      let t = cg.newTemp()
      cg.emit(t & " = load i8*, i8** " & g)
      return (cg.strLive(t), "i8*")
    elif ft == dtFloat:
      let t = cg.newTemp()
      cg.emit(t & " = load double, double* " & g)
      return (t, "double")
    let t = cg.newTemp()
    cg.emit(t & " = load i32, i32* " & g)
    return (t, "i32")

  of nkListAccess:
    # Listas de registros primero: resolverlas no debe tocar otras tablas.
    if n.left != nil and n.left.kind == nkIdent and cg.recListKindOf(n.left) == dtListRecord:
      let lp = cg.rlistPtr(n.left)
      if n.strVal == "longitud":
        let t = cg.newTemp()
        cg.emit(t & " = call i32 @coma_rlist_len(%CRecList* " & lp & ")")
        return (t, "i32")
      # Renglón suelto: solo vive dentro de `Campo de ...` (sema lo exige).
      return ("0", "i32")
    var accLp = ""
    var accStr = false
    var accList = false
    if n.left != nil and n.left.kind == nkIdent:
      accStr = cg.listKindIsStr(n.left)
      accList = not accStr and cg.listKindIsList(n.left)
      accLp = if accStr: cg.slistPtr(n.left) elif accList: cg.llistPtr(n.left) else: cg.listPtr(n.left)
    else:
      # Valor-lista directo (Elemento 1 de Elemento 2 de M): se materializa.
      let (lv, lt) = cg.genExpr(n.left)
      if lt == "%CList" or lt == "%CListStr" or lt == "%CListList":
        let tmp = cg.newTemp()
        cg.emit(tmp & " = alloca " & lt)
        cg.emit("store " & lt & " " & lv & ", " & lt & "* " & tmp)
        accLp = tmp
        accStr = lt == "%CListStr"
        accList = lt == "%CListList"
    if accLp.len == 0:
      if accStr: return ("null", "i8*")
      return ("0", "i32")
    if accList:
      let lp = accLp
      if n.strVal == "longitud":
        let t = cg.newTemp()
        cg.emit(t & " = call i32 @coma_llist_len(%CListList* " & lp & ")")
        return (t, "i32")
      var idxV = ""
      if n.strVal == "primero":
        idxV = "0"
      elif n.strVal == "ultimo":
        let ln = cg.newTemp()
        cg.emit(ln & " = call i32 @coma_llist_len(%CListList* " & lp & ")")
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & ln & ", 1")
        idxV = t
      else:
        let (iv, it) = cg.genExpr(n.right)
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
        idxV = t
      let tmp = cg.newTemp()
      cg.emit(tmp & " = alloca %CList")
      cg.emit("call void @coma_llist_get(%CListList* " & lp & ", i32 " & idxV & ", %CList* " & tmp & ")")
      let v = cg.newTemp()
      cg.emit(v & " = load %CList, %CList* " & tmp)
      return (v, "%CList")
    if accStr:
      let lp = accLp
      if n.strVal == "longitud":
        let t = cg.newTemp()
        cg.emit(t & " = call i32 @coma_slist_len(%CListStr* " & lp & ")")
        return (t, "i32")
      var idxV = ""
      if n.strVal == "primero":
        idxV = "0"
      elif n.strVal == "ultimo":
        let ln = cg.newTemp()
        cg.emit(ln & " = call i32 @coma_slist_len(%CListStr* " & lp & ")")
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & ln & ", 1")
        idxV = t
      else:
        let (iv, it) = cg.genExpr(n.right)
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
        idxV = t
      let v = cg.newTemp()
      cg.emit(v & " = call i8* @coma_slist_get(%CListStr* " & lp & ", i32 " & idxV & ")")
      return (cg.strLive(v), "i8*")
    let lp = accLp
    if n.strVal == "longitud":
      let t = cg.newTemp()
      cg.emit(t & " = call i32 @coma_list_len(%CList* " & lp & ")")
      return (t, "i32")
    # primero / ultimo / elemento idx (E101 dentro del runtime)
    var idxV = ""
    if n.strVal == "primero":
      idxV = "0"
    elif n.strVal == "ultimo":
      let ln = cg.newTemp()
      cg.emit(ln & " = call i32 @coma_list_len(%CList* " & lp & ")")
      let t = cg.newTemp()
      cg.emit(t & " = sub i32 " & ln & ", 1")
      idxV = t
    else:
      let (iv, it) = cg.genExpr(n.right)
      let t = cg.newTemp()
      cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
      idxV = t
    let v = cg.newTemp()
    cg.emit(v & " = call i32 @coma_list_get(%CList* " & lp & ", i32 " & idxV & ")")
    return (v, "i32")

  else:
    return ("0", "i32")

proc storeToVar(cg: var CodeGen, name: string, v, ty: string) =
  ## Asignación tipada (heap para texto: sin tope 256).
  if cg.inFunction and cg.locals.hasKey(name):
    let lt = if cg.localTyps.hasKey(name): cg.localTyps[name] else: dtInt
    if lt == dtString:
      cg.emit("call void @coma_str_assign(i8** " & cg.locals[name] & ", i8* " & v & ")")
    elif lt == dtFloat:
      if ty == "double":
        cg.emit("store double " & v & ", double* " & cg.locals[name])
      else:
        cg.emit("store double " & cg.toDouble(v, ty) & ", double* " & cg.locals[name])
    else:
      cg.emit("store i32 " & cg.toI32(v, ty) & ", i32* " & cg.locals[name])
    return
  let want = cg.symTyp(name)
  if want == dtString or (want == dtUnknown and ty == "i8*"):
    let g = cg.ensureStrGlobal(name)
    cg.emit("call void @coma_str_assign(i8** " & g & ", i8* " & v & ")")
  elif want == dtFloat or (want == dtUnknown and ty == "double"):
    let g = cg.ensureFloatGlobal(name)
    if ty == "double":
      cg.emit("store double " & v & ", double* " & g)
    else:
      let d = cg.toDouble(v, ty)
      cg.emit("store double " & d & ", double* " & g)
  else:
    let g = cg.ensureIntGlobal(name)
    cg.emit("store i32 " & cg.toI32(v, ty) & ", i32* " & g)

proc flushSucia(cg: var CodeGen, newVal: int) =
  cg.emit("store i8 " & $newVal & ", i8* @.sucia")

proc emitRecRow(cg: var CodeGen, lp: string, rowIdx: int, row: Node, schema: seq[string]) =
  ## Agrega un renglón (registro ident o literal) a la lista de registros.
  cg.emit("call void @coma_rlist_addrow(%CRecList* " & lp & ")")
  if row == nil: return
  if row.kind == nkRecordLit:
    for f in row.fields:
      var col = -1
      for i, s in schema:
        if s == f.name: col = i
      if col < 0: continue
      let (v, ty) = cg.genExpr(f.val)
      cg.emit("call void @coma_rlist_set(%CRecList* " & lp & ", i32 " & $rowIdx & ", i32 " & $col & ", i32 " & cg.toI32(v, ty) & ")")
  elif row.kind == nkIdent:
    for i, s in schema:
      let acc = Node(kind: nkFieldAccess, line: row.line, col: row.col, left: row, strVal: s)
      let (v, ty) = cg.genExpr(acc)
      cg.emit("call void @coma_rlist_set(%CRecList* " & lp & ", i32 " & $rowIdx & ", i32 " & $i & ", i32 " & cg.toI32(v, ty) & ")")

proc genStmt*(cg: var CodeGen, n: Node) =
  if n == nil: return

  case n.kind
  of nkAssign:
    # Registro: campos tipados (primera escritura manda).
    if n.left != nil and n.left.kind == nkRecordLit:
      for f in n.left.fields:
        let (v, ty) = cg.genExpr(f.val)
        let g = cg.ensureRecField(n.identName, f.name, typOfVal(ty))
        if ty == "i8*":
          cg.emit("call void @coma_str_assign(i8** " & g & ", i8* " & v & ")")
        elif ty == "double":
          cg.emit("store double " & v & ", double* " & g)
        else:
          cg.emit("store i32 " & cg.toI32(v, ty) & ", i32* " & g)
      return
    # Lista de registros (literal o bloque): resetea con esquema y agrega filas.
    if n.left != nil and n.left.kind == nkListRecordLit:
      let lp = cg.rlistPtr(Node(kind: nkIdent, identName: n.identName))
      let schema = cg.recSchemaOf(n.left)
      cg.emit("call void @coma_rlist_reset(%CRecList* " & lp & ", i32 " & $schema.len & ")")
      var ri = 0
      for row in n.left.children:
        cg.emitRecRow(lp, ri, row, schema)
        inc ri
      return
    # Lista literal: reset + agregar (heap, sin tope).
    if n.left != nil and n.left.kind == nkListLit:
      if n.left.typ == dtListRecord:
        let lp = cg.rlistPtr(Node(kind: nkIdent, identName: n.identName))
        let schema = cg.recSchemaOf(n.left)
        cg.emit("call void @coma_rlist_reset(%CRecList* " & lp & ", i32 " & $schema.len & ")")
        var ri = 0
        for row in n.left.children:
          cg.emitRecRow(lp, ri, row, schema)
          inc ri
        return
      if cg.listKindIsList(Node(kind: nkIdent, identName: n.identName)):
        let lp = cg.llistPtr(Node(kind: nkIdent, identName: n.identName))
        cg.emit("call void @coma_llist_reset(%CListList* " & lp & ")")
        for child in n.left.children:
          let (v, ty) = cg.genExpr(child)
          var pv = v
          if ty == "%CList":
            let tmp = cg.newTemp()
            cg.emit(tmp & " = alloca %CList")
            cg.emit("store %CList " & v & ", %CList* " & tmp)
            pv = tmp
          elif ty != "%CList*":
            let tmp = cg.newTemp()
            cg.emit(tmp & " = alloca %CList")
            cg.emit("store %CList zeroinitializer, %CList* " & tmp)
            pv = tmp
          cg.emit("call void @coma_llist_add(%CListList* " & lp & ", %CList* " & pv & ")")
        return
      if cg.listKindIsStr(Node(kind: nkIdent, identName: n.identName)):
        let lp = cg.slistPtr(Node(kind: nkIdent, identName: n.identName))
        cg.emit("call void @coma_slist_reset(%CListStr* " & lp & ")")
        for child in n.left.children:
          let (v, ty) = cg.genExpr(child)
          var sv = v
          if ty != "i8*":
            let e = cg.getStrConst("")
            sv = cg.newTemp()
            cg.emit(sv & " = getelementptr inbounds [1 x i8], [1 x i8]* " & e & ", i32 0, i32 0")
          cg.emit("call void @coma_slist_add(%CListStr* " & lp & ", i8* " & sv & ")")
        return
      let lp = cg.listPtr(Node(kind: nkIdent, identName: n.identName))
      cg.emit("call void @coma_list_reset(%CList* " & lp & ")")
      for child in n.left.children:
        let (v, ty) = cg.genExpr(child)
        cg.emit("call void @coma_list_add(%CList* " & lp & ", i32 " & cg.toI32(v, ty) & ")")
      return
    let (v, ty) = cg.genExpr(n.left)
    # Retorno-lista de llamada: copia profunda (semántica de valor).
    if ty == "%CList":
      let lp = cg.listPtr(Node(kind: nkIdent, identName: n.identName))
      let tmp = cg.newTemp()
      cg.emit(tmp & " = alloca %CList")
      cg.emit("store %CList " & v & ", %CList* " & tmp)
      cg.emit("call void @coma_list_copy(%CList* " & lp & ", %CList* " & tmp & ")")
      return
    # Copia lista de texto a lista de texto (L2 igual L1): copia profunda.
    if ty == "%CListStr*":
      let lp = cg.slistPtr(Node(kind: nkIdent, identName: n.identName))
      cg.emit("call void @coma_slist_copy(%CListStr* " & lp & ", %CListStr* " & v & ")")
      return
    # Retorno-lista de texto de llamada: copia profunda (semántica de valor).
    if ty == "%CListStr":
      let lp = cg.slistPtr(Node(kind: nkIdent, identName: n.identName))
      let tmp = cg.newTemp()
      cg.emit(tmp & " = alloca %CListStr")
      cg.emit("store %CListStr " & v & ", %CListStr* " & tmp)
      cg.emit("call void @coma_slist_copy(%CListStr* " & lp & ", %CListStr* " & tmp & ")")
      return
    # Copia lista de listas (M2 igual M1): copia profunda.
    if ty == "%CListList*":
      let lp = cg.llistPtr(Node(kind: nkIdent, identName: n.identName))
      cg.emit("call void @coma_llist_copy(%CListList* " & lp & ", %CListList* " & v & ")")
      return
    # Copia lista de registros (H igual G.): copia profunda.
    if ty == "%CRecList*":
      let lp = cg.rlistPtr(Node(kind: nkIdent, identName: n.identName))
      cg.emit("call void @coma_rlist_copy(%CRecList* " & lp & ", %CRecList* " & v & ")")
      return
    # Retorno-lista de listas de llamada: copia profunda (semántica de valor).
    if ty == "%CListList":
      let lp = cg.llistPtr(Node(kind: nkIdent, identName: n.identName))
      let tmp = cg.newTemp()
      cg.emit(tmp & " = alloca %CListList")
      cg.emit("store %CListList " & v & ", %CListList* " & tmp)
      cg.emit("call void @coma_llist_copy(%CListList* " & lp & ", %CListList* " & tmp & ")")
      return
    cg.storeToVar(n.identName, v, ty)
    # Capturada de closure: escribir a la global del entorno (sobrescribe el local).
    if cg.curCaptured.hasKey(n.identName):
      let g = cg.curCaptured[n.identName]
      let lt = cg.capturedGlobals[n.identName]
      if lt == dtString:
        cg.emit("call void @coma_str_assign(i8** " & g & ", i8* " & v & ")")
      elif lt == dtFloat:
        cg.emit("store double " & v & ", double* " & g)
      else:
        cg.emit("store i32 " & cg.toI32(v, ty) & ", i32* " & g)
      return

  of nkFieldAssign:
    # `Vida de E igual X.` / `Vida de elemento 2 de G igual X.`
    if n.left != nil and n.left.kind == nkIdent and cg.recIters.hasKey(n.left.identName):
      let lst = cg.recIters[n.left.identName]
      let col = cg.recListCol(lst, n.strVal)
      if col >= 0:
        let lp = cg.rlistPtr(Node(kind: nkIdent, identName: lst))
        var rowV = ""
        if cg.inFunction and cg.locals.hasKey(n.left.identName):
          let t = cg.newTemp()
          cg.emit(t & " = load i32, i32* " & cg.locals[n.left.identName])
          rowV = t
        else:
          let g = cg.ensureIntGlobal(n.left.identName)
          let t = cg.newTemp()
          cg.emit(t & " = load i32, i32* " & g)
          rowV = t
        let r0 = cg.newTemp()
        cg.emit(r0 & " = sub i32 " & rowV & ", 1")
        let (v, ty) = cg.genExpr(n.right)
        cg.emit("call void @coma_rlist_set(%CRecList* " & lp & ", i32 " & r0 & ", i32 " & $col & ", i32 " & cg.toI32(v, ty) & ")")
        return
    if n.left != nil and n.left.kind == nkListAccess:
      let inner = n.left.left
      if inner != nil and inner.kind == nkIdent:
        let (lfound, lsym) = cg.semaCtx.globalScope.findSym(inner.identName)
        if lfound and lsym.typ == dtListRecord:
          var col = -1
          for i, f in lsym.fields:
            if f == n.strVal: col = i
          if col >= 0:
            let lp = cg.rlistPtr(inner)
            let (iv, it) = cg.genExpr(n.left.right)
            var r0 = ""
            if n.left.strVal == "primero":
              r0 = "0"
            elif n.left.strVal == "ultimo":
              let ln = cg.newTemp()
              cg.emit(ln & " = call i32 @coma_rlist_len(%CRecList* " & lp & ")")
              let t = cg.newTemp()
              cg.emit(t & " = sub i32 " & ln & ", 1")
              r0 = t
            else:
              r0 = cg.newTemp()
              cg.emit(r0 & " = sub i32 " & cg.toI32(iv, it) & ", 1")
            let (v, ty) = cg.genExpr(n.right)
            cg.emit("call void @coma_rlist_set(%CRecList* " & lp & ", i32 " & r0 & ", i32 " & $col & ", i32 " & cg.toI32(v, ty) & ")")
            return
    var recName = ""
    if n.left.kind == nkIdent: recName = n.left.identName
    else:
      let (rv, _) = cg.genExpr(n.left)
      discard rv
      recName = "?"
    let (v, ty) = cg.genExpr(n.right)
    let g = cg.ensureRecField(recName, n.strVal, typOfVal(ty))
    if ty == "i8*":
      cg.emit("call void @coma_str_assign(i8** " & g & ", i8* " & v & ")")
    elif ty == "double":
      cg.emit("store double " & v & ", double* " & g)
    else:
      cg.emit("store i32 " & cg.toI32(v, ty) & ", i32* " & g)

  of nkListAssign:
    if cg.listKindIsList(n.left):
      let lp = cg.llistPtr(n.left)
      if lp.len == 0: return
      let (vv, vt) = cg.genExpr(n.target)
      var pv = vv
      if vt == "%CList":
        let tmp = cg.newTemp()
        cg.emit(tmp & " = alloca %CList")
        cg.emit("store %CList " & vv & ", %CList* " & tmp)
        pv = tmp
      elif vt != "%CList*":
        let tmp = cg.newTemp()
        cg.emit(tmp & " = alloca %CList")
        cg.emit("store %CList zeroinitializer, %CList* " & tmp)
        pv = tmp
      var idxV = ""
      if n.strVal == "primero": idxV = "0"
      elif n.strVal == "ultimo":
        let ln = cg.newTemp()
        cg.emit(ln & " = call i32 @coma_llist_len(%CListList* " & lp & ")")
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & ln & ", 1")
        idxV = t
      else:
        let (iv, it) = cg.genExpr(n.right)
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
        idxV = t
      cg.emit("call void @coma_llist_set(%CListList* " & lp & ", i32 " & idxV & ", %CList* " & pv & ")")
      return
    if cg.listKindIsStr(n.left):
      let lp = cg.slistPtr(n.left)
      if lp.len == 0: return
      let (vv, vt) = cg.genExpr(n.target)
      var sval = vv
      if vt != "i8*":
        let e = cg.getStrConst("")
        sval = cg.newTemp()
        cg.emit(sval & " = getelementptr inbounds [1 x i8], [1 x i8]* " & e & ", i32 0, i32 0")
      var idxV = ""
      if n.strVal == "primero": idxV = "0"
      elif n.strVal == "ultimo":
        let ln = cg.newTemp()
        cg.emit(ln & " = call i32 @coma_slist_len(%CListStr* " & lp & ")")
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & ln & ", 1")
        idxV = t
      else:
        let (iv, it) = cg.genExpr(n.right)
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
        idxV = t
      cg.emit("call void @coma_slist_set(%CListStr* " & lp & ", i32 " & idxV & ", i8* " & sval & ")")
      return
    let lp = cg.listPtr(n.left)
    if lp.len == 0: return
    let (vv, vt) = cg.genExpr(n.target)
    let val = cg.toI32(vv, vt)
    var idxV = ""
    if n.strVal == "primero": idxV = "0"
    elif n.strVal == "ultimo":
      let ln = cg.newTemp()
      cg.emit(ln & " = call i32 @coma_list_len(%CList* " & lp & ")")
      let t = cg.newTemp()
      cg.emit(t & " = sub i32 " & ln & ", 1")
      idxV = t
    else:
      let (iv, it) = cg.genExpr(n.right)
      let t = cg.newTemp()
      cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
      idxV = t
    cg.emit("call void @coma_list_set(%CList* " & lp & ", i32 " & idxV & ", i32 " & val & ")")

  of nkMostrar:
    # si venía racha pisa, bajar de línea primero
    let s = cg.newTemp()
    cg.emit(s & " = load i8, i8* @.sucia")
    let dirty = cg.newTemp()
    cg.emit(dirty & " = icmp ne i8 " & s & ", 0")
    let nlL = cg.newLabel("mnl")
    let mcL = cg.newLabel("mcont")
    cg.emit("br i1 " & dirty & ", label %" & nlL & ", label %" & mcL)
    cg.lines.add(nlL & ":")
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_s0, i32 0, i32 0), i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.nl, i32 0, i32 0))")
    cg.flushSucia(0)
    cg.emit("br label %" & mcL)
    cg.lines.add(mcL & ":")
    for item in n.children:
      let (v, ty) = cg.genExpr(item)
      if ty == "i8*":
        cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_s, i32 0, i32 0), i8* " & v & ")")
      elif ty == "double":
        cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_f, i32 0, i32 0), double " & v & ")")
      elif ty == "i1":
        let e = cg.newTemp()
        cg.emit(e & " = zext i1 " & v & " to i32")
        cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_d, i32 0, i32 0), i32 " & e & ")")
      else:
        cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_d, i32 0, i32 0), i32 " & cg.toI32(v, ty) & ")")
      cg.emit("call i32 @fflush(i8* null)")

  of nkPedir:
    # pedir respeta el tipo previo (E103 con reintento); si es nueva, texto.
    let typ = cg.symTyp(n.identName)
    if typ == dtInt:
      let g = cg.ensureIntGlobal(n.identName)
      let t = cg.newTemp()
      cg.emit(t & " = call i32 @coma_pedir_int(i32* " & g & ")")
    elif typ == dtFloat:
      let g = cg.ensureFloatGlobal(n.identName)
      let t = cg.newTemp()
      cg.emit(t & " = call i32 @coma_pedir_dbl(double* " & g & ")")
    else:
      let g = cg.ensureStrGlobal(n.identName)
      cg.emit("call void @coma_pedir(i8** " & g & ")")

  of nkArchivo:
    # abrir/crear/eliminar "ruta" (+cerrar sin nada). E105 honesto en rt.
    if n.strVal == "cerrar":
      cg.emit("call void @coma_f_close()")
    else:
      var pv = ""
      if n.left != nil:
        let (lv, lt) = cg.genExpr(n.left)
        if lt == "i8*":
          pv = lv
        else:
          let e = cg.getStrConst("")
          pv = cg.newTemp()
          cg.emit(pv & " = getelementptr inbounds [1 x i8], [1 x i8]* " & e & ", i32 0, i32 0")
      let fnCall = case n.strVal
        of "abrir": "coma_f_open"
        of "crear": "coma_f_create"
        else: "coma_f_delete"
      cg.emit("call void @" & fnCall & "(i8* " & pv & ")")

  of nkLeerLinea:
    let g = cg.ensureStrGlobal(n.identName)
    cg.emit("call void @coma_f_read(i8** " & g & ")")

  of nkEscribir:
    let (v, ty) = cg.genExpr(n.left)
    if ty == "i8*":
      cg.emit("call void @coma_f_write_str(i8* " & v & ")")
    elif ty == "double":
      cg.emit("call void @coma_f_write_dbl(double " & v & ")")
    else:
      cg.emit("call void @coma_f_write_int(i32 " & cg.toI32(v, ty) & ")")

  of nkRed:
    # Red en sesión única TCP. Errores duros = E106 en rt.
    if n.strVal == "conectar":
      var hv = ""
      if n.left != nil:
        let (lv, lt) = cg.genExpr(n.left)
        if lt == "i8*":
          hv = lv
        else:
          let e = cg.getStrConst("")
          hv = cg.newTemp()
          cg.emit(hv & " = getelementptr inbounds [1 x i8], [1 x i8]* " & e & ", i32 0, i32 0")
      var pv = "80"
      if n.right != nil:
        let (rv, rt) = cg.genExpr(n.right)
        pv = cg.toI32(rv, rt)
      cg.emit("call void @coma_net_connect(i8* " & hv & ", i32 " & pv & ")")
    elif n.strVal == "enviar":
      let (v, ty) = cg.genExpr(n.left)
      if ty == "i8*":
        cg.emit("call void @coma_net_send_str(i8* " & v & ")")
      elif ty == "double":
        cg.emit("call void @coma_net_send_dbl(double " & v & ")")
      else:
        cg.emit("call void @coma_net_send_int(i32 " & cg.toI32(v, ty) & ")")
    elif n.strVal == "recibir":
      let g = cg.ensureStrGlobal(n.identName)
      cg.emit("call void @coma_net_recv(i8** " & g & ")")
    else:
      cg.emit("call void @coma_net_close()")

  of nkPisa:
    let s = cg.newTemp()
    cg.emit(s & " = load i8, i8* @.sucia")
    let clean = cg.newTemp()
    cg.emit(clean & " = icmp eq i8 " & s & ", 0")
    let clL = cg.newLabel("pclear")
    let pcL = cg.newLabel("pcont")
    cg.emit("br i1 " & clean & ", label %" & clL & ", label %" & pcL)
    cg.lines.add(clL & ":")
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([83 x i8], [83 x i8]* @.clearline, i32 0, i32 0))")
    cg.flushSucia(1)
    cg.emit("br label %" & pcL)
    cg.lines.add(pcL & ":")
    let (v, ty) = cg.genExpr(n.left)
    if ty == "i8*":
      cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_s0, i32 0, i32 0), i8* " & v & ")")
    elif ty == "double":
      cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_g0, i32 0, i32 0), double " & v & ")")
    elif ty == "i1":
      let e = cg.newTemp()
      cg.emit(e & " = zext i1 " & v & " to i32")
      cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_d0, i32 0, i32 0), i32 " & e & ")")
    else:
      cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_d0, i32 0, i32 0), i32 " & cg.toI32(v, ty) & ")")
    cg.emit("call i32 @fflush(i8* null)")

  of nkIf:
    let (condVal, condTy) = cg.genExpr(n.cond)
    let c = cg.toI1(condVal, condTy)
    let thenL = cg.newLabel("entonces")
    let elseL = cg.newLabel("sino")
    let endL = cg.newLabel("fin")
    let hasElse = n.elseBlock != nil
    let hadLbl = n.label.len > 0
    if hadLbl: cg.breakLabels[n.label] = endL
    cg.emit("br i1 " & c & ", label %" & thenL & ", label %" & (if hasElse: elseL else: endL))
    cg.lines.add(thenL & ":")
    cg.genStmt(n.thenBlock)
    cg.emit("br label %" & endL)
    if hasElse:
      cg.lines.add(elseL & ":")
      cg.genStmt(n.elseBlock)
      cg.emit("br label %" & endL)
    cg.lines.add(endL & ":")
    if hadLbl: cg.breakLabels.del(n.label)

  of nkWhile:
    let loopL = cg.newLabel("bucle")
    let bodyL = cg.newLabel("cuerpo")
    let endL = cg.newLabel("finbucle")
    cg.breakStack.add(endL)
    cg.continueStack.add(loopL)
    let hadLbl = n.label.len > 0
    if hadLbl:
      cg.breakLabels[n.label] = endL
      cg.contLabels[n.label] = loopL
    cg.emit("br label %" & loopL)
    cg.lines.add(loopL & ":")
    let (condVal, condTy) = cg.genExpr(n.cond)
    let c = cg.toI1(condVal, condTy)
    cg.emit("br i1 " & c & ", label %" & bodyL & ", label %" & endL)
    cg.lines.add(bodyL & ":")
    cg.genStmt(n.thenBlock)
    cg.emit("br label %" & loopL)
    cg.lines.add(endL & ":")
    discard cg.breakStack.pop()
    discard cg.continueStack.pop()
    if hadLbl:
      cg.breakLabels.del(n.label)
      cg.contLabels.del(n.label)

  of nkTick:
    cg.usesTecla = true
    cg.usesTime = true
    let tickL = cg.newLabel("tick")
    let endL = cg.newLabel("fintick")
    cg.breakStack.add(endL)
    cg.continueStack.add(tickL)
    let hadLbl = n.label.len > 0
    if hadLbl:
      cg.breakLabels[n.label] = endL
      cg.contLabels[n.label] = tickL
    cg.emit("br label %" & tickL)
    cg.lines.add(tickL & ":")
    # Muestreo no bloqueante (el runtime mapea flechas/minúsculas)
    cg.emitKeyPoll()
    cg.genStmt(n.thenBlock)
    # Tiempo y espera del frame
    if n.intVal > 0:
      let dval = 1.0 / float(n.intVal)
      let dold = cg.newTemp()
      cg.emit(dold & " = load double, double* @.delta")
      discard dold
      cg.emit("store double " & $dval & ", double* @.delta")
      let told = cg.newTemp()
      cg.emit(told & " = load double, double* @.tiempo")
      let tnew = cg.newTemp()
      cg.emit(tnew & " = fadd double " & told & ", " & $dval)
      cg.emit("store double " & tnew & ", double* @.tiempo")
      cg.emit("call void @coma_tick_wait(i32 " & $(int(1000 / n.intVal)) & ")")
    else:
      let told = cg.newTemp()
      cg.emit(told & " = load double, double* @.tiempo")
      let tnew = cg.newTemp()
      cg.emit(tnew & " = fadd double " & told & ", 0.016000e+00")
      cg.emit("store double " & tnew & ", double* @.tiempo")
      cg.emit("store double 0.016000e+00, double* @.delta")
    cg.emit("br label %" & tickL)
    cg.lines.add(endL & ":")
    discard cg.breakStack.pop()
    discard cg.continueStack.pop()
    if hadLbl:
      cg.breakLabels.del(n.label)
      cg.contLabels.del(n.label)

  of nkMatch:
    let (matchVal, matchTy) = cg.genExpr(n.cond)
    let endMatch = cg.newLabel("finsegun")
    let hadLbl = n.label.len > 0
    if hadLbl: cg.breakLabels[n.label] = endMatch
    for bIdx, branch in n.children:
      let nextBranch = cg.newLabel("casosig")
      let matchBranch = cg.newLabel("casocuerpo")
      discard bIdx
      var condAcc = ""
      var first = true
      for vIdx, vNode in branch.children:
        discard vIdx
        let (valChoice, vTy) = cg.genExpr(vNode)
        let tcmp = cg.newTemp()
        if matchTy == "i8*" or vTy == "i8*":
          # comparar como texto: convertir ints a... solo vale texto-texto; si uno no es texto, falso
          if matchTy == "i8*" and vTy == "i8*":
            let ts = cg.newTemp()
            cg.emit(ts & " = call i32 @strcmp(i8* " & matchVal & ", i8* " & valChoice & ")")
            cg.emit(tcmp & " = icmp eq i32 " & ts & ", 0")
          else:
            cg.emit(tcmp & " = icmp eq i1 0, 1")
        else:
          let a = cg.toI32(matchVal, matchTy)
          let b = cg.toI32(valChoice, vTy)
          cg.emit(tcmp & " = icmp eq i32 " & a & ", " & b)
        if first:
          condAcc = tcmp
          first = false
        else:
          let tor = cg.newTemp()
          cg.emit(tor & " = or i1 " & condAcc & ", " & tcmp)
          condAcc = tor
      if condAcc == "":
        condAcc = "false"
      cg.emit("br i1 " & condAcc & ", label %" & matchBranch & ", label %" & nextBranch)
      cg.lines.add(matchBranch & ":")
      cg.genStmt(branch.thenBlock)
      cg.emit("br label %" & endMatch)
      cg.lines.add(nextBranch & ":")
    if n.elseBlock != nil:
      cg.genStmt(n.elseBlock)
    cg.emit("br label %" & endMatch)
    cg.lines.add(endMatch & ":")
    if hadLbl: cg.breakLabels.del(n.label)

  of nkForEach:
    # por cada X en Lista de registros: X es la POSICIÓN (1-based, v0.4).
    if n.left != nil and n.left.kind == nkIdent and cg.recListKindOf(n.left) == dtListRecord:
      let lp = cg.rlistPtr(n.left)
      if lp.len == 0: return
      let iterG = if cg.inFunction and cg.locals.hasKey(n.identName): cg.locals[n.identName]
                  else: cg.ensureIntGlobal(n.identName)
      let idxA = "%" & sanitize(n.identName) & "_idx" & $cg.labelId
      inc cg.labelId
      cg.emit(idxA & " = alloca i32")
      cg.emit("store i32 0, i32* " & idxA)
      let loopL = cg.newLabel("cada")
      let bodyL = cg.newLabel("cadab")
      let endL = cg.newLabel("cadafin")
      cg.breakStack.add(endL)
      cg.continueStack.add(loopL)
      let hadLbl = n.label.len > 0
      if hadLbl:
        cg.breakLabels[n.label] = endL
        cg.contLabels[n.label] = loopL
      cg.emit("br label %" & loopL)
      cg.lines.add(loopL & ":")
      let iv = cg.newTemp()
      cg.emit(iv & " = load i32, i32* " & idxA)
      let ln = cg.newTemp()
      cg.emit(ln & " = call i32 @coma_rlist_len(%CRecList* " & lp & ")")
      let cc = cg.newTemp()
      cg.emit(cc & " = icmp slt i32 " & iv & ", " & ln)
      cg.emit("br i1 " & cc & ", label %" & bodyL & ", label %" & endL)
      cg.lines.add(bodyL & ":")
      let pos = cg.newTemp()
      cg.emit(pos & " = add i32 " & iv & ", 1")
      cg.emit("store i32 " & pos & ", i32* " & iterG)
      let hadRec = cg.recIters.hasKey(n.identName)
      var oldRec = ""
      if hadRec: oldRec = cg.recIters[n.identName]
      cg.recIters[n.identName] = n.left.identName
      cg.genStmt(n.thenBlock)
      if hadRec: cg.recIters[n.identName] = oldRec
      else: cg.recIters.del(n.identName)
      let iv2 = cg.newTemp()
      cg.emit(iv2 & " = load i32, i32* " & idxA)
      let nx = cg.newTemp()
      cg.emit(nx & " = add i32 " & iv2 & ", 1")
      cg.emit("store i32 " & nx & ", i32* " & idxA)
      cg.emit("br label %" & loopL)
      cg.lines.add(endL & ":")
      discard cg.breakStack.pop()
      discard cg.continueStack.pop()
      if hadLbl:
        cg.breakLabels.del(n.label)
        cg.contLabels.del(n.label)
      return
    # por cada X en Lista: X = copia del elemento (int/texto/fila, heap)
    let isStr = cg.listKindIsStr(n.left)
    let isList = not isStr and cg.listKindIsList(n.left)
    let lp = if isStr: cg.slistPtr(n.left) elif isList: cg.llistPtr(n.left) else: cg.listPtr(n.left)
    if lp.len == 0: return
    # En funcion, el iterador es local (pre-escaneado); fuera, global.
    let iterG = if cg.inFunction and cg.locals.hasKey(n.identName): cg.locals[n.identName]
                elif isStr: cg.ensureStrGlobal(n.identName)
                elif isList: cg.ensureList(n.identName)
                else: cg.ensureIntGlobal(n.identName)
    let listTy = if isStr: "%CListStr" elif isList: "%CListList" else: "%CList"
    let lenFn = if isStr: "coma_slist_len" elif isList: "coma_llist_len" else: "coma_list_len"
    let getFn = if isStr: "coma_slist_get" elif isList: "coma_llist_get" else: "coma_list_get"
    let idxA = "%" & sanitize(n.identName) & "_idx" & $cg.labelId
    inc cg.labelId
    cg.emit(idxA & " = alloca i32")
    cg.emit("store i32 0, i32* " & idxA)
    let loopL = cg.newLabel("cada")
    let bodyL = cg.newLabel("cadab")
    let endL = cg.newLabel("cadafin")
    cg.breakStack.add(endL)
    cg.continueStack.add(loopL)
    let hadLbl = n.label.len > 0
    if hadLbl:
      cg.breakLabels[n.label] = endL
      cg.contLabels[n.label] = loopL
    cg.emit("br label %" & loopL)
    cg.lines.add(loopL & ":")
    let iv = cg.newTemp()
    cg.emit(iv & " = load i32, i32* " & idxA)
    let ln = cg.newTemp()
    cg.emit(ln & " = call i32 @" & lenFn & "(" & listTy & "* " & lp & ")")
    let cc = cg.newTemp()
    cg.emit(cc & " = icmp slt i32 " & iv & ", " & ln)
    cg.emit("br i1 " & cc & ", label %" & bodyL & ", label %" & endL)
    cg.lines.add(bodyL & ":")
    let iterKind = if cg.inFunction and cg.locals.hasKey(n.identName):
                     if cg.localTyps.hasKey(n.identName): cg.localTyps[n.identName] else: dtInt
                   elif isStr: dtString
                   elif isList: dtList
                   else: dtInt
    let ev = cg.newTemp()
    if iterKind == dtString:
      cg.emit(ev & " = call i8* @" & getFn & "(" & listTy & "* " & lp & ", i32 " & iv & ")")
      cg.emit("call void @coma_str_assign(i8** " & iterG & ", i8* " & ev & ")")
    elif iterKind == dtList:
      let tmp = cg.newTemp()
      cg.emit(tmp & " = alloca %CList")
      cg.emit("call void @" & getFn & "(" & listTy & "* " & lp & ", i32 " & iv & ", %CList* " & tmp & ")")
      cg.emit("call void @coma_list_copy(%CList* " & iterG & ", %CList* " & tmp & ")")
    else:
      cg.emit(ev & " = call i32 @" & getFn & "(" & listTy & "* " & lp & ", i32 " & iv & ")")
      cg.emit("store i32 " & ev & ", i32* " & iterG)
    cg.genStmt(n.thenBlock)
    let iv2 = cg.newTemp()
    cg.emit(iv2 & " = load i32, i32* " & idxA)
    let nx = cg.newTemp()
    cg.emit(nx & " = add i32 " & iv2 & ", 1")
    cg.emit("store i32 " & nx & ", i32* " & idxA)
    cg.emit("br label %" & loopL)
    cg.lines.add(endL & ":")
    discard cg.breakStack.pop()
    discard cg.continueStack.pop()
    if hadLbl:
      cg.breakLabels.del(n.label)
      cg.contLabels.del(n.label)

  of nkComprobar:
    let (testMsg, _) = cg.genExpr(Node(kind: nkStr, strVal: "[TEST] " & n.strVal & "\n"))
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_s0, i32 0, i32 0), i8* " & testMsg & ")")
    cg.emit("call i32 @fflush(i8* null)")
    if n.thenBlock != nil and n.thenBlock.kind == nkBlock:
      for stmt in n.thenBlock.children:
        var exprNode = stmt
        if stmt.kind == nkExprStmt:
          exprNode = stmt.left
        let (val, ty) = cg.genExpr(exprNode)
        let cond = cg.toI1(val, ty)
        let okL = cg.newLabel("testok")
        let failL = cg.newLabel("testfail")
        cg.emit("br i1 " & cond & ", label %" & okL & ", label %" & failL)
        cg.lines.add(failL & ":")
        let (failMsg, _) = cg.genExpr(Node(kind: nkStr, strVal: "[FAIL] Test fallido: " & n.strVal & "\n"))
        cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_s0, i32 0, i32 0), i8* " & failMsg & ")")
        cg.emit("call void @exit(i32 1)")
        cg.emit("unreachable")
        cg.lines.add(okL & ":")
    let (passMsg, _) = cg.genExpr(Node(kind: nkStr, strVal: "[OK] Test pasado: " & n.strVal & "\n"))
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_s0, i32 0, i32 0), i8* " & passMsg & ")")
    cg.emit("call i32 @fflush(i8* null)")

  of nkPara:
    # Salto incondicional: lo que sigue en este bloque sería un 2º terminador
    # (LLVM inválido / `para` anulado). Se abre un bloque muerto y listo.
    if n.label.len > 0 and cg.breakLabels.hasKey(n.label):
      cg.emit("br label %" & cg.breakLabels[n.label])
    elif cg.breakStack.len > 0:
      cg.emit("br label %" & cg.breakStack[^1])
    else:
      cg.emit("unreachable")
    let deadP = cg.newLabel("dead")
    cg.lines.add(deadP & ":")

  of nkSigue:
    if n.label.len > 0 and cg.contLabels.hasKey(n.label):
      cg.emit("br label %" & cg.contLabels[n.label])
    elif cg.continueStack.len > 0:
      cg.emit("br label %" & cg.continueStack[^1])
    else:
      cg.emit("unreachable")
    let deadS = cg.newLabel("dead")
    cg.lines.add(deadS & ":")

  of nkFinLabel:
    if n.label.len > 0 and cg.breakLabels.hasKey(n.label):
      cg.emit("br label %" & cg.breakLabels[n.label])
    else:
      cg.emit("unreachable")
    let deadF = cg.newLabel("dead")
    cg.lines.add(deadF & ":")

  of nkDevolver:
    let (v, ty) = cg.genExpr(n.left)
    if cg.curRetTyp == dtList:
      # Retorno-lista por valor (el llamante copia a su variable).
      if ty == "%CList":
        cg.emit("ret %CList " & v)
      elif ty == "%CList*":
        let ld = cg.newTemp()
        cg.emit(ld & " = load %CList, %CList* " & v)
        cg.emit("ret %CList " & ld)
      else:
        cg.emit("ret %CList zeroinitializer")
    elif cg.curRetTyp == dtListStr:
      if ty == "%CListStr":
        cg.emit("ret %CListStr " & v)
      elif ty == "%CListStr*":
        let ld = cg.newTemp()
        cg.emit(ld & " = load %CListStr, %CListStr* " & v)
        cg.emit("ret %CListStr " & ld)
      else:
        cg.emit("ret %CListStr zeroinitializer")
    elif cg.curRetTyp == dtListList:
      if ty == "%CListList":
        cg.emit("ret %CListList " & v)
      elif ty == "%CListList*":
        let ld = cg.newTemp()
        cg.emit(ld & " = load %CListList, %CListList* " & v)
        cg.emit("ret %CListList " & ld)
      else:
        cg.emit("ret %CListList zeroinitializer")
    elif cg.curRetTyp == dtString:
      # El texto vuelve en el buffer @g_ret_F (uno por funcion, sin reentrancia).
      let dst = cg.newTemp()
      cg.emit(dst & " = getelementptr inbounds [" & $StrBuf & " x i8], [" & $StrBuf & " x i8]* " & cg.curRetBuf & ", i32 0, i32 0")
      cg.emit("store i8 0, i8* " & dst)
      if ty == "i8*":
        cg.emit("call i8* @strncpy(i8* " & dst & ", i8* " & v & ", i64 255)")
      let z = cg.newTemp()
      cg.emit(z & " = getelementptr inbounds [" & $StrBuf & " x i8], [" & $StrBuf & " x i8]* " & cg.curRetBuf & ", i32 0, i32 255")
      cg.emit("store i8 0, i8* " & z)
      cg.emit("ret i8* " & dst)
    elif cg.curRetTyp == dtFloat:
      cg.emit("ret double " & cg.toDouble(v, ty))
    else:
      if ty == "double":
        let i = cg.newTemp()
        cg.emit(i & " = fptosi double " & v & " to i32")
        cg.emit("ret i32 " & i)
      else:
        cg.emit("ret i32 " & cg.toI32(v, ty))
    let deadR = cg.newLabel("dead")
    cg.lines.add(deadR & ":")

  of nkExprStmt:
    discard cg.genExpr(n.left)

  of nkEsperar:
    let (v, ty) = cg.genExpr(n.left)
    if ty == "double":
      let ms = cg.newTemp()
      cg.emit(ms & " = fmul double " & v & ", 1000.0")
      let msi = cg.newTemp()
      cg.emit(msi & " = fptosi double " & ms & " to i32")
      cg.emit("call void @coma_sleep_ms(i32 " & msi & ")")
    else:
      let ms = cg.newTemp()
      cg.emit(ms & " = mul i32 " & cg.toI32(v, ty) & ", 1000")
      cg.emit("call void @coma_sleep_ms(i32 " & ms & ")")

  of nkLimpiar:
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.clearscreen, i32 0, i32 0))")
    cg.emit("call i32 @fflush(i8* null)")
    cg.flushSucia(0)
    cg.emit("store i8 1, i8* @.firstdraw")
    cg.emit("store i8 1, i8* @.dirty")
    # forzar redibujo: prev = 0xFF
    let cells8 = cg.newTemp()
    cg.emit(cells8 & " = bitcast [" & $BoardCells & " x [" & $CellBytes & " x i8]]* @.prev to i8*")
    cg.emit("call i8* @memset(i8* " & cells8 & ", i32 255, i64 " & $BoardBytes & ")")
    cg.emit("store i32 -9999, i32* @.prevx")

  of nkLienzo:
    cg.usesBoard = true
    let (wv, wt) = cg.genExpr(n.left)
    let (hv, ht) = cg.genExpr(n.right)
    let w = cg.toI32(wv, wt)
    let h = cg.toI32(hv, ht)
    # cotas 1..40, si no E202
    let ok1 = cg.newTemp()
    cg.emit(ok1 & " = icmp sge i32 " & w & ", 1")
    let ok2 = cg.newTemp()
    cg.emit(ok2 & " = icmp sle i32 " & w & ", 40")
    let ok3 = cg.newTemp()
    cg.emit(ok3 & " = icmp sge i32 " & h & ", 1")
    let ok4 = cg.newTemp()
    cg.emit(ok4 & " = icmp sle i32 " & h & ", 40")
    let o12 = cg.newTemp()
    cg.emit(o12 & " = and i1 " & ok1 & ", " & ok2)
    let o34 = cg.newTemp()
    cg.emit(o34 & " = and i1 " & ok3 & ", " & ok4)
    let ok = cg.newTemp()
    cg.emit(ok & " = and i1 " & o12 & ", " & o34)
    let okL = cg.newLabel("liok")
    let badL = cg.newLabel("li202")
    cg.emit("br i1 " & ok & ", label %" & okL & ", label %" & badL)
    cg.lines.add(badL & ":")
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.e202l, i32 0, i32 0))")
    cg.emit("call void @exit(i32 1)")
    cg.emit("unreachable")
    cg.lines.add(okL & ":")
    cg.emit("store i32 " & w & ", i32* @.bw")
    cg.emit("store i32 " & h & ", i32* @.bh")
    let c8 = cg.newTemp()
    cg.emit(c8 & " = bitcast [" & $BoardCells & " x [" & $CellBytes & " x i8]]* @.cells to i8*")
    cg.emit("call i8* @memset(i8* " & c8 & ", i32 0, i64 " & $BoardBytes & ")")
    cg.emit("store i8 1, i8* @.dirty")

  of nkMarca:
    cg.usesBoard = true
    let (xv, xt) = cg.genExpr(n.left)
    let (yv, yt) = cg.genExpr(n.right)
    let xi = cg.toI32(xv, xt)
    let yi = cg.toI32(yv, yt)
    let w = cg.newTemp()
    cg.emit(w & " = load i32, i32* @.bw")
    let h = cg.newTemp()
    cg.emit(h & " = load i32, i32* @.bh")
    let okx1 = cg.newTemp()
    cg.emit(okx1 & " = icmp sge i32 " & xi & ", 0")
    let okx2 = cg.newTemp()
    cg.emit(okx2 & " = icmp slt i32 " & xi & ", " & w)
    let oky1 = cg.newTemp()
    cg.emit(oky1 & " = icmp sge i32 " & yi & ", 0")
    let oky2 = cg.newTemp()
    cg.emit(oky2 & " = icmp slt i32 " & yi & ", " & h)
    let o1 = cg.newTemp()
    cg.emit(o1 & " = and i1 " & okx1 & ", " & okx2)
    let o2 = cg.newTemp()
    cg.emit(o2 & " = and i1 " & oky1 & ", " & oky2)
    let ok = cg.newTemp()
    cg.emit(ok & " = and i1 " & o1 & ", " & o2)
    let okL = cg.newLabel("mok")
    let endL = cg.newLabel("mfin")
    cg.emit("br i1 " & ok & ", label %" & okL & ", label %" & endL)
    cg.lines.add(okL & ":")
    let idx1 = cg.newTemp()
    cg.emit(idx1 & " = mul i32 " & yi & ", " & $BoardMax)
    let idx2 = cg.newTemp()
    cg.emit(idx2 & " = add i32 " & idx1 & ", " & xi)
    let cellp = cg.newTemp()
    cg.emit(cellp & " = getelementptr inbounds [" & $BoardCells & " x [" & $CellBytes & " x i8]], [" & $BoardCells & " x [" & $CellBytes & " x i8]]* @.cells, i32 0, i32 " & idx2 & ", i32 0")
    var glyphPtr = ""
    var glyphTy = ""
    if n.strVal == "muro":
      let c = cg.getStrConst("█")
      let t = cg.newTemp()
      cg.emit(t & " = getelementptr inbounds [4 x i8], [4 x i8]* " & c & ", i32 0, i32 0")
      glyphPtr = t; glyphTy = "lit"
    elif n.strVal == "moneda":
      let c = cg.getStrConst("○")
      let t = cg.newTemp()
      cg.emit(t & " = getelementptr inbounds [4 x i8], [4 x i8]* " & c & ", i32 0, i32 0")
      glyphPtr = t; glyphTy = "lit"
      cg.emit("store i32 " & xi & ", i32* @.coinx")
      cg.emit("store i32 " & yi & ", i32* @.coiny")
    elif n.strVal == "meta":
      let c = cg.getStrConst("♦")
      let t = cg.newTemp()
      cg.emit(t & " = getelementptr inbounds [4 x i8], [4 x i8]* " & c & ", i32 0, i32 0")
      glyphPtr = t; glyphTy = "lit"
      cg.emit("store i32 " & xi & ", i32* @.metax")
      cg.emit("store i32 " & yi & ", i32* @.metay")
    else:
      let (gv, gt) = cg.genExpr(n.target)
      if gt == "i8*":
        glyphPtr = gv; glyphTy = "ptr"
      else:
        let c = cg.getStrConst("")
        let t = cg.newTemp()
        cg.emit(t & " = getelementptr inbounds [1 x i8], [1 x i8]* " & c & ", i32 0, i32 0")
        glyphPtr = t; glyphTy = "lit"
    discard glyphTy
    cg.emit("call i8* @strncpy(i8* " & cellp & ", i8* " & glyphPtr & ", i64 7)")
    cg.emit("store i8 1, i8* @.dirty")
    cg.emit("br label %" & endL)
    cg.lines.add(endL & ":")

  of nkTablero:
    cg.usesBoard = true
    let (xv, xt) = cg.genExpr(n.left)
    let (yv, yt) = cg.genExpr(n.right)
    let xi = cg.toI32(xv, xt)
    let yi = cg.toI32(yv, yt)
    var takenV = "0"
    if n.target != nil:
      let (tv, tt) = cg.genExpr(n.target)
      takenV = cg.toI32(tv, tt)
    # dirty por bandera (la pone marca/lienzo): cero escaneo por frame.
    # El C espejo hace memcmp+memcpy (polling); esto es event-driven.
    let dirtyB = cg.newTemp()
    cg.emit(dirtyB & " = load i8, i8* @.dirty")
    let cellsDiff = cg.newTemp()
    cg.emit(cellsDiff & " = icmp ne i8 " & dirtyB & ", 0")
    let px = cg.newTemp()
    cg.emit(px & " = load i32, i32* @.prevx")
    let xDiff = cg.newTemp()
    cg.emit(xDiff & " = icmp ne i32 " & px & ", " & xi)
    let py = cg.newTemp()
    cg.emit(py & " = load i32, i32* @.prevy")
    let yDiff = cg.newTemp()
    cg.emit(yDiff & " = icmp ne i32 " & py & ", " & yi)
    let pt = cg.newTemp()
    cg.emit(pt & " = load i32, i32* @.prevtaken")
    let tDiff = cg.newTemp()
    cg.emit(tDiff & " = icmp ne i32 " & pt & ", " & takenV)
    let d1 = cg.newTemp()
    cg.emit(d1 & " = or i1 " & cellsDiff & ", " & xDiff)
    let d2 = cg.newTemp()
    cg.emit(d2 & " = or i1 " & yDiff & ", " & tDiff)
    let need = cg.newTemp()
    cg.emit(need & " = or i1 " & d1 & ", " & d2)
    let drawL = cg.newLabel("draw")
    let skipL = cg.newLabel("skipdraw")
    cg.emit("br i1 " & need & ", label %" & drawL & ", label %" & skipL)
    cg.lines.add(drawL & ":")
    cg.emit("store i32 " & xi & ", i32* @.prevx")
    cg.emit("store i32 " & yi & ", i32* @.prevy")
    cg.emit("store i32 " & takenV & ", i32* @.prevtaken")
    cg.emit("store i8 0, i8* @.dirty")
    # bucles y/x
    let w = cg.newTemp()
    cg.emit(w & " = load i32, i32* @.bw")
    let h = cg.newTemp()
    cg.emit(h & " = load i32, i32* @.bh")
    # reposicionar: primer dibujo directo; resto subir (alto+1: tablero+HUD)
    let fd = cg.newTemp()
    cg.emit(fd & " = load i8, i8* @.firstdraw")
    let isFirst = cg.newTemp()
    cg.emit(isFirst & " = icmp ne i8 " & fd & ", 0")
    let noMoveL = cg.newLabel("nomove")
    let moveL = cg.newLabel("move")
    let rowsL = cg.newLabel("rows")
    cg.emit("br i1 " & isFirst & ", label %" & noMoveL & ", label %" & moveL)
    cg.lines.add(moveL & ":")
    let upN = cg.newTemp()
    cg.emit(upN & " = add i32 " & h & ", 1")
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.mvup, i32 0, i32 0), i32 " & upN & ")")
    cg.emit("br label %" & rowsL)
    cg.lines.add(noMoveL & ":")
    cg.emit("br label %" & rowsL)
    cg.lines.add(rowsL & ":")
    # Frame en global (como el C: cero allocas por dibujo, todo a registros).
    cg.emit("store i32 0, i32* @.fpos")
    let frameA = "@.frame"
    let posA = "@.fpos"
    let floorC = cg.getStrConst("·")
    let heroC = cg.getStrConst("☺")
    let coinC = cg.getStrConst("○")
    let floorP = cg.newTemp()
    cg.emit(floorP & " = getelementptr inbounds [4 x i8], [4 x i8]* " & floorC & ", i32 0, i32 0")
    let heroP = cg.newTemp()
    cg.emit(heroP & " = getelementptr inbounds [4 x i8], [4 x i8]* " & heroC & ", i32 0, i32 0")
    # Longitudes una sola vez (valen cualquier glifo futuro).
    let floorL64 = cg.newTemp()
    cg.emit(floorL64 & " = call i64 @strlen(i8* " & floorP & ")")
    let floorLn = cg.newTemp()
    cg.emit(floorLn & " = trunc i64 " & floorL64 & " to i32")
    let heroL64 = cg.newTemp()
    cg.emit(heroL64 & " = call i64 @strlen(i8* " & heroP & ")")
    let heroLn = cg.newTemp()
    cg.emit(heroLn & " = trunc i64 " & heroL64 & " to i32")
    let yA = "@.taby"
    let xA = "@.tabx"
    cg.emit("store i32 0, i32* " & yA)
    let yLoop = cg.newLabel("taby")
    let yBody = cg.newLabel("tabyb")
    let yEnd = cg.newLabel("tabye")
    let xLoop = cg.newLabel("tabx")
    let xBody = cg.newLabel("tabxb")
    let xEnd = cg.newLabel("tabxe")
    cg.emit("br label %" & yLoop)
    cg.lines.add(yLoop & ":")
    let yv2 = cg.newTemp()
    cg.emit(yv2 & " = load i32, i32* " & yA)
    let ycc = cg.newTemp()
    cg.emit(ycc & " = icmp slt i32 " & yv2 & ", " & h)
    cg.emit("br i1 " & ycc & ", label %" & yBody & ", label %" & yEnd)
    cg.lines.add(yBody & ":")
    cg.emit("store i32 0, i32* " & xA)
    cg.emit("br label %" & xLoop)
    cg.lines.add(xLoop & ":")
    let xv2 = cg.newTemp()
    cg.emit(xv2 & " = load i32, i32* " & xA)
    let xcc = cg.newTemp()
    cg.emit(xcc & " = icmp slt i32 " & xv2 & ", " & w)
    cg.emit("br i1 " & xcc & ", label %" & xBody & ", label %" & xEnd)
    cg.lines.add(xBody & ":")
    # idx = y*40+x
    let i1 = cg.newTemp()
    cg.emit(i1 & " = mul i32 " & yv2 & ", " & $BoardMax)
    let i2 = cg.newTemp()
    cg.emit(i2 & " = add i32 " & i1 & ", " & xv2)
    let cellp = cg.newTemp()
    cg.emit(cellp & " = getelementptr inbounds [" & $BoardCells & " x [" & $CellBytes & " x i8]], [" & $BoardCells & " x [" & $CellBytes & " x i8]]* @.cells, i32 0, i32 " & i2 & ", i32 0")
    # ¿es jugador?
    let isx = cg.newTemp()
    cg.emit(isx & " = icmp eq i32 " & xv2 & ", " & xi)
    let isy = cg.newTemp()
    cg.emit(isy & " = icmp eq i32 " & yv2 & ", " & yi)
    let isHero = cg.newTemp()
    cg.emit(isHero & " = and i1 " & isx & ", " & isy)
    let heroL = cg.newLabel("hero")
    let cellL = cg.newLabel("cell")
    let prL = cg.newLabel("pr")
    cg.emit("br i1 " & isHero & ", label %" & heroL & ", label %" & cellL)
    cg.lines.add(heroL & ":")
    cg.framePut(frameA, posA, heroP, heroLn)
    cg.emit("br label %" & prL)
    cg.lines.add(cellL & ":")
    # ¿moneda cogida y celda es moneda? -> suelo. Sin taken literal no hay
    # ni diamante (el optimizador lo agradecerá; C tampoco lo tendría).
    var hideCoin = "false"
    if takenV != "0":
      let takenB = cg.newTemp()
      cg.emit(takenB & " = icmp ne i32 " & takenV & ", 0")
      let coinChkL = cg.newLabel("coinchk")
      let coinNoL = cg.newLabel("coinno")
      let coinJoinL = cg.newLabel("coinjoin")
      cg.emit("br i1 " & takenB & ", label %" & coinChkL & ", label %" & coinNoL)
      cg.lines.add(coinChkL & ":")
      let cn = cg.newTemp()
      cg.emit(cn & " = call i32 @strcmp(i8* " & cellp & ", i8* getelementptr inbounds ([4 x i8], [4 x i8]* " & coinC & ", i32 0, i32 0))")
      let isCoin = cg.newTemp()
      cg.emit(isCoin & " = icmp eq i32 " & cn & ", 0")
      cg.emit("br label %" & coinJoinL)
      cg.lines.add(coinNoL & ":")
      cg.emit("br label %" & coinJoinL)
      cg.lines.add(coinJoinL & ":")
      let hc = cg.newTemp()
      cg.emit(hc & " = phi i1 [ false, %" & coinNoL & " ], [ " & isCoin & ", %" & coinChkL & " ]")
      hideCoin = hc
    let flL = cg.newLabel("floor")
    let showL = cg.newLabel("show")
    cg.emit("br i1 " & hideCoin & ", label %" & flL & ", label %" & showL)
    cg.lines.add(flL & ":")
    cg.framePut(frameA, posA, floorP, floorLn)
    cg.emit("br label %" & prL)
    cg.lines.add(showL & ":")
    # celda vacía -> suelo, si no la celda
    let ln = cg.newTemp()
    cg.emit(ln & " = call i64 @strlen(i8* " & cellp & ")")
    let empty = cg.newTemp()
    cg.emit(empty & " = icmp eq i64 " & ln & ", 0")
    let eL = cg.newLabel("empty")
    let fL = cg.newLabel("full")
    cg.emit("br i1 " & empty & ", label %" & eL & ", label %" & fL)
    cg.lines.add(eL & ":")
    cg.framePut(frameA, posA, floorP, floorLn)
    cg.emit("br label %" & prL)
    cg.lines.add(fL & ":")
    let ln32 = cg.newTemp()
    cg.emit(ln32 & " = trunc i64 " & ln & " to i32")
    cg.framePut(frameA, posA, cellp, ln32)
    cg.emit("br label %" & prL)
    cg.lines.add(prL & ":")
    let xn = cg.newTemp()
    cg.emit(xn & " = add i32 " & xv2 & ", 1")
    cg.emit("store i32 " & xn & ", i32* " & xA)
    cg.emit("br label %" & xLoop)
    cg.lines.add(xEnd & ":")
    cg.frameByte(frameA, posA, 10)
    let yn = cg.newTemp()
    cg.emit(yn & " = add i32 " & yv2 & ", 1")
    cg.emit("store i32 " & yn & ", i32* " & yA)
    cg.emit("br label %" & yLoop)
    cg.lines.add(yEnd & ":")
    # UN printf gordo con todo el frame (la corona del §23, de verdad).
    cg.frameByte(frameA, posA, 0)
    let fr0 = cg.newTemp()
    cg.emit(fr0 & " = getelementptr inbounds [" & $FrameBytes & " x i8], [" & $FrameBytes & " x i8]* " & frameA & ", i32 0, i32 0")
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.fmt_s0, i32 0, i32 0), i8* " & fr0 & ")")
    cg.emit("call i32 @fflush(i8* null)")
    cg.emit("store i8 0, i8* @.firstdraw")
    # línea HUD virgen para la racha de pisas que sigue (y fin: no caer
    # al skip, que reimprimiría otra limpieza)
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([83 x i8], [83 x i8]* @.clearline, i32 0, i32 0))")
    cg.flushSucia(1)
    let endTab = cg.newLabel("fintab")
    cg.emit("br label %" & endTab)
    cg.lines.add(skipL & ":")
    # aunque el tablero no cambie, el HUD sí: reabrir su línea
    cg.emit("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([83 x i8], [83 x i8]* @.clearline, i32 0, i32 0))")
    cg.flushSucia(1)
    cg.emit("br label %" & endTab)
    cg.lines.add(endTab & ":")

  of nkListAdd:
    if cg.listKindIsList(n.left):
      let lp = cg.llistPtr(n.left)
      if lp.len == 0: return
      let (vv, vt) = cg.genExpr(n.right)
      var pv = vv
      if vt == "%CList":
        let tmp = cg.newTemp()
        cg.emit(tmp & " = alloca %CList")
        cg.emit("store %CList " & vv & ", %CList* " & tmp)
        pv = tmp
      elif vt != "%CList*":
        let tmp = cg.newTemp()
        cg.emit(tmp & " = alloca %CList")
        cg.emit("store %CList zeroinitializer, %CList* " & tmp)
        pv = tmp
      cg.emit("call void @coma_llist_add(%CListList* " & lp & ", %CList* " & pv & ")")
      return
    if cg.listKindIsStr(n.left):
      let lp = cg.slistPtr(n.left)
      if lp.len == 0: return
      let (vv, vt) = cg.genExpr(n.right)
      var sv = vv
      if vt != "i8*":
        let e = cg.getStrConst("")
        sv = cg.newTemp()
        cg.emit(sv & " = getelementptr inbounds [1 x i8], [1 x i8]* " & e & ", i32 0, i32 0")
      cg.emit("call void @coma_slist_add(%CListStr* " & lp & ", i8* " & sv & ")")
      return
    let lp = cg.listPtr(n.left)
    if lp.len == 0: return
    let (vv, vt) = cg.genExpr(n.right)
    cg.emit("call void @coma_list_add(%CList* " & lp & ", i32 " & cg.toI32(vv, vt) & ")")

  of nkListRemove:
    if cg.listKindIsList(n.left):
      let lp = cg.llistPtr(n.left)
      if lp.len == 0: return
      if n.strVal in ["primero", "ultimo", "elemento"]:
        var idxV = ""
        if n.strVal == "primero": idxV = "0"
        elif n.strVal == "ultimo":
          let ln = cg.newTemp()
          cg.emit(ln & " = call i32 @coma_llist_len(%CListList* " & lp & ")")
          let t = cg.newTemp()
          cg.emit(t & " = sub i32 " & ln & ", 1")
          idxV = t
        else:
          let (iv, it) = cg.genExpr(n.right)
          let t = cg.newTemp()
          cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
          idxV = t
        cg.emit("call void @coma_llist_rmat(%CListList* " & lp & ", i32 " & idxV & ")")
      else:
        let (vv, vt) = cg.genExpr(n.right)
        var pv = vv
        if vt == "%CList":
          let tmp = cg.newTemp()
          cg.emit(tmp & " = alloca %CList")
          cg.emit("store %CList " & vv & ", %CList* " & tmp)
          pv = tmp
        elif vt != "%CList*":
          let tmp = cg.newTemp()
          cg.emit(tmp & " = alloca %CList")
          cg.emit("store %CList zeroinitializer, %CList* " & tmp)
          pv = tmp
        cg.emit("call void @coma_llist_rmval(%CListList* " & lp & ", %CList* " & pv & ")")
      return
    if cg.listKindIsStr(n.left):
      let lp = cg.slistPtr(n.left)
      if lp.len == 0: return
      if n.strVal in ["primero", "ultimo", "elemento"]:
        var idxV = ""
        if n.strVal == "primero": idxV = "0"
        elif n.strVal == "ultimo":
          let ln = cg.newTemp()
          cg.emit(ln & " = call i32 @coma_slist_len(%CListStr* " & lp & ")")
          let t = cg.newTemp()
          cg.emit(t & " = sub i32 " & ln & ", 1")
          idxV = t
        else:
          let (iv, it) = cg.genExpr(n.right)
          let t = cg.newTemp()
          cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
          idxV = t
        cg.emit("call void @coma_slist_rmat(%CListStr* " & lp & ", i32 " & idxV & ")")
      else:
        let (vv, vt) = cg.genExpr(n.right)
        var sv = vv
        if vt != "i8*":
          let e = cg.getStrConst("")
          sv = cg.newTemp()
          cg.emit(sv & " = getelementptr inbounds [1 x i8], [1 x i8]* " & e & ", i32 0, i32 0")
        cg.emit("call void @coma_slist_rmval(%CListStr* " & lp & ", i8* " & sv & ")")
      return
    let lp = cg.listPtr(n.left)
    if lp.len == 0: return
    if n.strVal in ["primero", "ultimo", "elemento"]:
      # quitar por posición (E101 dentro del runtime)
      var idxV = ""
      if n.strVal == "primero": idxV = "0"
      elif n.strVal == "ultimo":
        let ln = cg.newTemp()
        cg.emit(ln & " = call i32 @coma_list_len(%CList* " & lp & ")")
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & ln & ", 1")
        idxV = t
      else:
        let (iv, it) = cg.genExpr(n.right)
        let t = cg.newTemp()
        cg.emit(t & " = sub i32 " & cg.toI32(iv, it) & ", 1")
        idxV = t
      cg.emit("call void @coma_list_rmat(%CList* " & lp & ", i32 " & idxV & ")")
    else:
      # quitar por valor (primera ocurrencia; callado si no está)
      let (vv, vt) = cg.genExpr(n.right)
      cg.emit("call void @coma_list_rmval(%CList* " & lp & ", i32 " & cg.toI32(vv, vt) & ")")

  of nkRecordBlock:
    for f in n.fields:
      let (v, ty) = cg.genExpr(f.val)
      let g = cg.ensureRecField(n.recordName, f.name, typOfVal(ty))
      if ty == "i8*":
        cg.emit("call void @coma_str_assign(i8** " & g & ", i8* " & v & ")")
      elif ty == "double":
        cg.emit("store double " & v & ", double* " & g)
      else:
        cg.emit("store i32 " & cg.toI32(v, ty) & ", i32* " & g)

  of nkPointerDecl:
    discard

  of nkBlock:
    for s in n.children:
      cg.genStmt(s)

  of nkFuncDecl:
    discard # se emiten hoisteadas en emitFuncs

  of nkCall:
    # Llamada suelta: se genera y se descarta el retorno.
    discard cg.genExpr(n)

  else:
    discard

proc collectFuncs(root: Node, outSeq: var seq[Node]) =
  if root == nil: return
  case root.kind
  of nkFuncDecl:
    outSeq.add(root)
    collectFuncs(root.thenBlock, outSeq)  # funciones anidadas (closures)
  of nkProgram, nkBlock:
    for c in root.children: collectFuncs(c, outSeq)
  else:
    if root.thenBlock != nil: collectFuncs(root.thenBlock, outSeq)
    if root.elseBlock != nil:
      if root.elseBlock.kind == nkIf or root.elseBlock.kind == nkBlock:
        collectFuncs(root.elseBlock, outSeq)
    for c in root.children: collectFuncs(c, outSeq)

proc emitFuncs(cg: var CodeGen, root: Node) =
  var funcs: seq[Node] = @[]
  collectFuncs(root, funcs)
  for stmt in funcs:
    cg.inFunction = true
    cg.locals.clear()
    cg.localTyps.clear()
    cg.curFuncName = stmt.funcName
    # Retorno inferido por sema (defecto entero).
    var retTy = dtInt
    let (rfound, rfsym) = cg.semaCtx.globalScope.findSym(stmt.funcName)
    if rfound and rfsym.kind == skFunc and rfsym.typ in {dtInt, dtFloat, dtString, dtList, dtListStr, dtListList}:
      retTy = rfsym.typ
    cg.curRetTyp = retTy
    cg.curRetBuf = ""
    cg.curFreeStr = @[]
    cg.curFreeList = @[]
    cg.curFreeSList = @[]
    cg.curFreeLList = @[]
    cg.curCaptured = initTable[string, string]()
    for vn, vt in cg.capturedGlobals:
      cg.curCaptured[vn] = case vt
        of dtString: cg.ensureStrGlobal(vn)
        of dtFloat: cg.ensureFloatGlobal(vn)
        else: cg.ensureIntGlobal(vn)
    let retDecl = if retTy == dtString: "i8*"
                  elif retTy == dtFloat: "double"
                  elif retTy == dtList: "%CList"
                  elif retTy == dtListStr: "%CListStr"
                  elif retTy == dtListList: "%CListList"
                  else: "i32"
    if retTy == dtString:
      cg.curRetBuf = cg.ensureStrGlobal("ret_" & stmt.funcName)
    let pts = stmt.paramTyps
    var paramDecl = ""
    for i, p in stmt.params:
      let pt = if i < pts.len: pts[i] else: dtInt
      # Punteros siempre noalias+nocapture: texto/listas entran por COPIA
      # (nada del llamante se guarda ni se muta a través del puntero).
      # C no puede prometer esto: todo le puede aliasar todo.
      let pd = if pt == dtString: "i8* noalias nocapture"
               elif pt == dtFloat: "double"
               elif pt == dtList: "%CList* noalias nocapture"
               elif pt == dtListStr: "%CListStr* noalias nocapture"
               elif pt == dtListList: "%CListList* noalias nocapture"
               else: "i32"
      if i > 0: paramDecl.add(", ")
      paramDecl.add(pd & " %" & sanitize(p))
    cg.lines.add("define " & retDecl & " @" & sanitize(stmt.funcName) & "(" & paramDecl & ") {")
    cg.lines.add("entry:")
    for i, p in stmt.params:
      let pt = if i < pts.len: pts[i] else: dtInt
      let pAddr = "%" & sanitize(stmt.funcName) & "_" & sanitize(p) & ".addr"
      cg.locals[p] = pAddr
      cg.localTyps[p] = pt
      if pt == dtString:
        # Copia de entrada (heap propio: reasignar libera sin tocar al llamante).
        cg.emit(pAddr & " = alloca i8*")
        cg.emit("call void @coma_str_assign(i8** " & pAddr & ", i8* %" & sanitize(p) & ")")
        cg.curFreeStr.add(p)
      elif pt == dtFloat:
        cg.emit(pAddr & " = alloca double")
        cg.emit("store double %" & sanitize(p) & ", double* " & pAddr)
      elif pt == dtList:
        # Listas por valor: copia profunda de entrada (sin aliasing fantasma).
        cg.emit(pAddr & " = alloca %CList")
        cg.emit("store %CList zeroinitializer, %CList* " & pAddr)
        cg.emit("call void @coma_list_copy(%CList* " & pAddr & ", %CList* %" & sanitize(p) & ")")
        cg.curFreeList.add(p)
      elif pt == dtListStr:
        cg.emit(pAddr & " = alloca %CListStr")
        cg.emit("store %CListStr zeroinitializer, %CListStr* " & pAddr)
        cg.emit("call void @coma_slist_copy(%CListStr* " & pAddr & ", %CListStr* %" & sanitize(p) & ")")
        cg.curFreeSList.add(p)
      elif pt == dtListList:
        cg.emit(pAddr & " = alloca %CListList")
        cg.emit("store %CListList zeroinitializer, %CListList* " & pAddr)
        cg.emit("call void @coma_llist_copy(%CListList* " & pAddr & ", %CListList* %" & sanitize(p) & ")")
        cg.curFreeLList.add(p)
      else:
        cg.emit(pAddr & " = alloca i32")
        cg.emit("store i32 %" & sanitize(p) & ", i32* " & pAddr)
    # Locales: pre-escaneo del cuerpo -> alloca + cero-init.
    var ltypes = initTable[string, DataTypeKind]()
    cg.collectBodyLocals(stmt.thenBlock, ltypes)
    for lname, lty in ltypes:
      if cg.locals.hasKey(lname): continue
      let a = "%" & sanitize(stmt.funcName) & "_" & sanitize(lname) & ".addr"
      cg.locals[lname] = a
      cg.localTyps[lname] = lty
      if lty == dtString:
        cg.emit(a & " = alloca i8*")
        cg.emit("store i8* null, i8** " & a)
        cg.curFreeStr.add(lname)
      elif lty == dtFloat:
        cg.emit(a & " = alloca double")
        cg.emit("store double 0.0, double* " & a)
      elif lty == dtList:
        cg.emit(a & " = alloca %CList")
        cg.emit("store %CList zeroinitializer, %CList* " & a)
        cg.curFreeList.add(lname)
      elif lty == dtListList:
        cg.emit(a & " = alloca %CListList")
        cg.emit("store %CListList zeroinitializer, %CListList* " & a)
        cg.curFreeLList.add(lname)
      elif lty == dtListStr:
        cg.emit(a & " = alloca %CListStr")
        cg.emit("store %CListStr zeroinitializer, %CListStr* " & a)
        cg.curFreeSList.add(lname)
      else:
        cg.emit(a & " = alloca i32")
        cg.emit("store i32 0, i32* " & a)
    cg.genStmt(stmt.thenBlock)
    cg.emitFreeLocals()
    if retTy == dtString:
      let z = cg.newTemp()
      cg.emit(z & " = load i8*, i8** " & cg.curRetBuf)
      cg.emit("ret i8* " & z)
    elif retTy == dtFloat:
      cg.emit("ret double 0.0")
    elif retTy == dtList:
      cg.emit("ret %CList zeroinitializer")
    elif retTy == dtListStr:
      cg.emit("ret %CListStr zeroinitializer")
    elif retTy == dtListList:
      cg.emit("ret %CListList zeroinitializer")
    else:
      cg.emit("ret i32 0")
    cg.lines.add("}")
    cg.lines.add("")
    cg.inFunction = false
    cg.curFuncName = ""
    cg.curRetTyp = dtInt
    cg.curRetBuf = ""
    cg.curFreeStr = @[]
    cg.curFreeList = @[]
    cg.curFreeSList = @[]
    cg.curFreeLList = @[]
  cg.locals.clear()
  cg.localTyps.clear()

proc collectClosureCaptures(n: Node, outTab: var Table[string, DataTypeKind]) =
  ## Recolecta variables locales del padre que son capturadas por funciones
  ## anidadas (capturedVars de cada nkFuncDecl). Se elevan a globals.
  if n == nil: return
  case n.kind
  of nkFuncDecl:
    for i in 0 ..< n.capturedVars.len:
      let vn = n.capturedVars[i]
      let vt = if i < n.capturedTyps.len: n.capturedTyps[i] else: dtInt
      if not outTab.hasKey(vn):
        outTab[vn] = vt
    collectClosureCaptures(n.thenBlock, outTab)
  of nkProgram, nkBlock:
    for c in n.children: collectClosureCaptures(c, outTab)
  else:
    if n.thenBlock != nil: collectClosureCaptures(n.thenBlock, outTab)
    if n.elseBlock != nil and n.elseBlock.kind in {nkBlock, nkIf}:
      collectClosureCaptures(n.elseBlock, outTab)
    for c in n.children: collectClosureCaptures(c, outTab)

proc closureGlobal(cg: var CodeGen, name: string, ty: DataTypeKind): string =
  case ty
  of dtString: return cg.ensureStrGlobal(name)
  of dtFloat: return cg.ensureFloatGlobal(name)
  else: return cg.ensureIntGlobal(name)

proc generateIR*(root: Node, semaCtx: SemaContext): string =
  var cg = newCodeGen(semaCtx)
  var bodyCg = newCodeGen(semaCtx)
  cg.usesAgmine = usesFirma(root)
  # Recolectar variables capturadas por closures y elevarlas a globals.
  collectClosureCaptures(root, bodyCg.capturedGlobals)
  bodyCg.emitFuncs(root)
  bodyCg.lines.add("define i32 @main() {")
  bodyCg.lines.add("entry:")
  # Consola: UTF-8 + VT vía runtime portable (en tubo se ignora solo)
  bodyCg.emit("call void @coma_console_init()")
  bodyCg.emit("call i64 @time(i64* null)")
  let tseed = bodyCg.newTemp()
  bodyCg.emit(tseed & " = call i64 @time(i64* null)")
  let iseed = bodyCg.newTemp()
  bodyCg.emit(iseed & " = trunc i64 " & tseed & " to i32")
  bodyCg.emit("call void @srand(i32 " & iseed & ")")
  proc genTop(n: Node) =
    if n == nil: return
    if n.kind == nkFuncDecl: return
    bodyCg.genStmt(n)
  for stmt in root.children:
    genTop(stmt)
  bodyCg.emit("ret i32 0")
  bodyCg.lines.add("}")
  cg.emitProlog()
  for strVal, symName in bodyCg.strConsts:
    let len = strVal.len + 1
    var escaped = ""
    for c in strVal:
      if c == '\"': escaped.add("\\22")
      elif c == '\\': escaped.add("\\5C")
      elif ord(c) in 32..126: escaped.add(c)
      else:
        escaped.add("\\" & toHex(ord(c), 2).toUpper())
    escaped.add("\\00")
    cg.lines.add(symName & " = private unnamed_addr constant [" & $len & " x i8] c\"" & escaped & "\"")
  for vName, symName in bodyCg.globals:
    cg.lines.add(symName & " = private global i32 0")
  for vName, symName in bodyCg.floatGlobals:
    cg.lines.add(symName & " = private global double 0.0")
  for vName, symName in bodyCg.strGlobals:
    cg.lines.add(symName & " = private global i8* null")
  for key, symName in bodyCg.recFields:
    let ft = if bodyCg.recFieldTyps.hasKey(key): bodyCg.recFieldTyps[key] else: dtInt
    if ft == dtString:
      cg.lines.add(symName & " = private global i8* null")
    elif ft == dtFloat:
      cg.lines.add(symName & " = private global double 0.0")
    else:
      cg.lines.add(symName & " = private global i32 0")
  for vName, symName in bodyCg.lists:
    cg.lines.add(symName & " = private global %CList zeroinitializer")
  for vName, symName in bodyCg.slists:
    cg.lines.add(symName & " = private global %CListStr zeroinitializer")
  for vName, symName in bodyCg.llists:
    cg.lines.add(symName & " = private global %CListList zeroinitializer")
  for vName, symName in bodyCg.rlists:
    cg.lines.add(symName & " = private global %CRecList zeroinitializer")
  cg.lines.add("")
  for l in bodyCg.lines:
    cg.lines.add(l)
  return cg.lines.join("\n") & "\n"
