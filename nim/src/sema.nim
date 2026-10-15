# sema.nim — Análisis semántico, tablas de símbolos e inferencia de tipos
import tables, strutils
import ast

type
  SymKind* = enum
    skGlobalVar,
    skLocalVar,
    skFunc,
    skRecord,
    skPointer

  Symbol* = object
    name*: string
    kind*: SymKind
    typ*: DataTypeKind
    intWidth*: int     # 8, 16, 32, 64
    fields*: seq[string]
    params*: seq[string]
    paramTyps*: seq[DataTypeKind] # paralelo a params (fase 1: entero/decimal/texto)
    targetVar*: string # si es puntero

  Scope* = ref object
    parent*: Scope
    symbols*: Table[string, Symbol]

  SemaContext* = object
    globalScope*: Scope
    currentScope*: Scope
    issues*: seq[Issue]
    inFunction*: bool
    currentFunc*: string
    recLoops*: seq[(string, string)] # (iterador, lista) de por_cada sobre registros

proc newScope*(parent: Scope = nil): Scope =
  result = Scope(parent: parent, symbols: initTable[string, Symbol]())

proc findSym*(s: Scope, name: string): (bool, Symbol) =
  var cur = s
  while cur != nil:
    if cur.symbols.hasKey(name):
      return (true, cur.symbols[name])
    cur = cur.parent
  return (false, Symbol())

proc declareSym*(s: Scope, sym: Symbol): bool =
  if s.symbols.hasKey(sym.name):
    return false # ya existe en este ámbito
  s.symbols[sym.name] = sym
  return true

proc tipoHumano*(t: DataTypeKind): string =
  case t
  of dtInt: "entero"
  of dtFloat: "decimal"
  of dtString: "texto"
  of dtBool: "booleano"
  of dtList: "lista"
  of dtListStr: "lista de texto"
  of dtListList: "lista de listas"
  of dtListRecord: "lista de registros"
  of dtRecord: "registro"
  else: "valor"

proc newSemaContext*(): SemaContext =
  result.globalScope = newScope()
  result.currentScope = result.globalScope
  result.issues = @[]
  result.inFunction = false
  result.currentFunc = ""
  result.recLoops = @[]
  # Firmas propias (ver ComaBuiltins en parser): existen siempre.
  discard result.globalScope.declareSym(Symbol(name: "Agmine", kind: skFunc, typ: dtInt,
                                              intWidth: 32, params: @[], paramTyps: @[]))

proc listKindOf(ctx: SemaContext, n: Node): DataTypeKind =
  ## Clase real de la lista nombrada (dtList por defecto si no se sabe).
  if n != nil and n.kind == nkIdent:
    let (found, sym) = ctx.currentScope.findSym(n.identName)
    if found and sym.typ in {dtList, dtListStr, dtListList, dtListRecord}:
      return sym.typ
  return dtList

proc recFieldList(ctx: SemaContext, target: Node): string =
  ## Si `Campo de X` es campo de lista de registros, devuelve la lista. "" si no.
  if target == nil: return ""
  if target.kind == nkIdent:
    for i in countdown(ctx.recLoops.high, 0):
      if ctx.recLoops[i][0] == target.identName:
        return ctx.recLoops[i][1]
    return ""
  if target.kind == nkListAccess:
    let l = target.left
    if l != nil and l.kind == nkIdent:
      let (found, sym) = ctx.currentScope.findSym(l.identName)
      if found and sym.typ == dtListRecord:
        return l.identName
  return ""

proc recordListFields(ctx: SemaContext, lit: Node): seq[string] =
  ## Esquema (unión en orden) de `lista J1 y J2` o bloque de renglones.
  result = @[]
  if lit == nil: return
  if lit.kind == nkListRecordLit:
    for row in lit.children:
      if row != nil and row.kind == nkRecordLit:
        for f in row.fields:
          if f.name notin result: result.add(f.name)
    return
  for child in lit.children:
    if child == nil: continue
    if child.kind == nkRecordLit:
      for f in child.fields:
        if f.name notin result: result.add(f.name)
    elif child.kind == nkIdent:
      let (found, sym) = ctx.currentScope.findSym(child.identName)
      if found and sym.typ == dtRecord:
        for fn in sym.fields:
          if fn notin result: result.add(fn)

# Primera pasada: Hoisting de firmas (recursivo: valen anidadas como Golpe)
proc preScanDeclarations*(ctx: var SemaContext, root: Node) =
  if root == nil: return
  case root.kind
  of nkFuncDecl:
    var pts: seq[DataTypeKind] = @[]
    for i in 0 ..< root.params.len:
      pts.add(if i < root.paramTyps.len: root.paramTyps[i] else: dtInt)
    var fnSym = Symbol(name: root.funcName, kind: skFunc, typ: dtInt,
                       params: root.params, paramTyps: pts)
    if not ctx.globalScope.declareSym(fnSym):
      ctx.issues.add(Issue(line: root.line, col: root.col, code: "E003", level: eError,
                           msg: "la funcion " & root.funcName & " ya esta declarada", hint: "usa otro nombre"))
    # OJO: no se baja al cuerpo (las funciones no se anidan, spec 10).
  of nkRecordBlock:
    var fNames: seq[string] = @[]
    for f in root.fields:
      fNames.add(f.name)
    var recSym = Symbol(name: root.recordName, kind: skRecord, typ: dtRecord, fields: fNames)
    discard ctx.globalScope.declareSym(recSym)
  of nkProgram, nkBlock:
    for c in root.children: preScanDeclarations(ctx, c)
  else:
    if root.thenBlock != nil: preScanDeclarations(ctx, root.thenBlock)
    if root.elseBlock != nil and root.elseBlock.kind in {nkBlock, nkIf}:
      preScanDeclarations(ctx, root.elseBlock)
    for c in root.children: preScanDeclarations(ctx, c)

proc analyzeExpr*(ctx: var SemaContext, n: Node): DataTypeKind

proc firstDevolver(n: Node): Node =
  ## Primer devolver en orden de fuente (para inferir el retorno).
  if n == nil: return nil
  case n.kind
  of nkDevolver: return n
  of nkFuncDecl: return nil
  of nkBlock, nkProgram:
    for c in n.children:
      let f = firstDevolver(c)
      if f != nil: return f
  else:
    if n.thenBlock != nil:
      let f = firstDevolver(n.thenBlock)
      if f != nil: return f
    if n.elseBlock != nil and n.elseBlock.kind in {nkBlock, nkIf}:
      let f2 = firstDevolver(n.elseBlock)
      if f2 != nil: return f2
    for c in n.children:
      let f3 = firstDevolver(c)
      if f3 != nil: return f3
  return nil

proc inferLitKind(ctx: SemaContext, lit: Node, fs: Scope): DataTypeKind =
  ## Clase de un `lista ...` para inferencia (mejor esfuerzo, sin issues).
  var nTexto = 0
  var nNum = 0
  var nList = 0
  var nOtro = 0
  for ch in lit.children:
    var t = dtUnknown
    case ch.kind
    of nkStr: t = dtString
    of nkInt, nkFloat, nkBool: t = dtInt
    of nkIdent:
      if fs.symbols.hasKey(ch.identName): t = fs.symbols[ch.identName].typ
      else:
        let (cfound, csym) = ctx.globalScope.findSym(ch.identName)
        if cfound: t = csym.typ
    of nkCall:
      let (cf, cs) = ctx.globalScope.findSym(ch.funcName)
      if cf and cs.kind == skFunc: t = cs.typ
    of nkListLit: t = ctx.inferLitKind(ch, fs)
    else: discard
    if t == dtString: inc nTexto
    elif t in {dtInt, dtFloat, dtBool}: inc nNum
    elif t == dtList: inc nList
    else: inc nOtro
  if nTexto > 0 and nTexto == lit.children.len: return dtListStr
  if nList > 0 and nList == lit.children.len: return dtListList
  return dtList

proc inferBodyNames(ctx: var SemaContext, body: Node, fs: Scope) =
  ## Declara en fs lo asignado en el cuerpo (mejor esfuerzo, sin issues):
  ## así `R igual lista ...` + `devolver R.` infiere bien (valía solo params).
  if body == nil: return
  case body.kind
  of nkAssign:
    if not fs.symbols.hasKey(body.identName) and body.left != nil:
      var t = dtInt
      case body.left.kind
      of nkInt: t = dtInt
      of nkFloat: t = dtFloat
      of nkStr: t = dtString
      of nkBool: t = dtBool
      of nkListLit: t = ctx.inferLitKind(body.left, fs)
      of nkIdent:
        if fs.symbols.hasKey(body.left.identName): t = fs.symbols[body.left.identName].typ
        else:
          let (cfound, csym) = ctx.globalScope.findSym(body.left.identName)
          if cfound: t = csym.typ
      of nkCall:
        let (cf, cs) = ctx.globalScope.findSym(body.left.funcName)
        if cf and cs.kind == skFunc and cs.typ in {dtInt, dtFloat, dtString, dtList, dtListStr, dtListList}:
          t = cs.typ
      of nkListAccess:
        if body.left.left != nil and body.left.left.kind == nkIdent:
          var lt = dtUnknown
          if fs.symbols.hasKey(body.left.left.identName): lt = fs.symbols[body.left.left.identName].typ
          else:
            let (lfound, lsym) = ctx.globalScope.findSym(body.left.left.identName)
            if lfound: lt = lsym.typ
          if lt == dtListStr: t = dtString
          elif lt == dtListList: t = dtList
      else: discard
      discard fs.declareSym(Symbol(name: body.identName, kind: skLocalVar, typ: t, intWidth: 32))
  of nkForEach:
    if not fs.symbols.hasKey(body.identName):
      var it = dtInt
      if body.left != nil and body.left.kind == nkIdent:
        var lt = dtUnknown
        if fs.symbols.hasKey(body.left.identName): lt = fs.symbols[body.left.identName].typ
        else:
          let (lfound, lsym) = ctx.globalScope.findSym(body.left.identName)
          if lfound: lt = lsym.typ
        if lt == dtListStr: it = dtString
        elif lt == dtListList: it = dtList
      discard fs.declareSym(Symbol(name: body.identName, kind: skLocalVar, typ: it, intWidth: 32))
    ctx.inferBodyNames(body.thenBlock, fs)
  of nkBlock, nkComprobar:
    for c in body.children: ctx.inferBodyNames(c, fs)
  else:
    if body.thenBlock != nil: ctx.inferBodyNames(body.thenBlock, fs)
    if body.elseBlock != nil and body.elseBlock.kind in {nkBlock, nkIf}:
      ctx.inferBodyNames(body.elseBlock, fs)
    for c in body.children: ctx.inferBodyNames(c, fs)

proc inferReturns(ctx: var SemaContext, root: Node) =
  ## Retorno = tipo del primer devolver (cero keywords nuevas, cero sintaxis).
  ## Sin devolver: entero (vale el `ret 0` de siempre).
  if root == nil: return
  if root.kind == nkFuncDecl:
    let d = firstDevolver(root.thenBlock)
    if d != nil and d.left != nil:
      let fs = newScope(ctx.globalScope)
      let (ff, fsym) = ctx.globalScope.findSym(root.funcName)
      if ff and fsym.kind == skFunc:
        for i, p in fsym.params:
          let pt = if i < fsym.paramTyps.len: fsym.paramTyps[i] else: dtInt
          discard fs.declareSym(Symbol(name: p, kind: skLocalVar, typ: pt, intWidth: 32))
      let oldScope = ctx.currentScope
      let oldFn = ctx.currentFunc
      let oldIn = ctx.inFunction
      ctx.currentScope = fs
      ctx.currentFunc = root.funcName
      ctx.inFunction = true
      ctx.inferBodyNames(root.thenBlock, fs)
      var t = ctx.analyzeExpr(d.left)
      if t == dtBool: t = dtInt
      ctx.currentScope = oldScope
      ctx.currentFunc = oldFn
      ctx.inFunction = oldIn
      if ff and fsym.kind == skFunc and t in {dtInt, dtFloat, dtString, dtList, dtListStr, dtListList}:
        var upd = fsym
        upd.typ = t
        ctx.globalScope.symbols[root.funcName] = upd
    return
  case root.kind
  of nkProgram, nkBlock:
    for c in root.children: inferReturns(ctx, c)
  else:
    if root.thenBlock != nil: inferReturns(ctx, root.thenBlock)
    if root.elseBlock != nil and root.elseBlock.kind in {nkBlock, nkIf}:
      inferReturns(ctx, root.elseBlock)
    for c in root.children: inferReturns(ctx, c)

# Inferencia de tipos y chequeo de expresiones
proc analyzeExpr*(ctx: var SemaContext, n: Node): DataTypeKind =
  if n == nil: return dtVoid

  case n.kind
  of nkInt:
    n.typ = dtInt
    # Ancho mínimo óptimo de entero
    if n.intVal >= -128 and n.intVal <= 127:
      n.intWidth = 8
    elif n.intVal >= -32768 and n.intVal <= 32767:
      n.intWidth = 16
    elif n.intVal >= -2147483648 and n.intVal <= 2147483647:
      n.intWidth = 32
    else:
      n.intWidth = 64
    return dtInt

  of nkFloat:
    n.typ = dtFloat
    return dtFloat

  of nkStr:
    n.typ = dtString
    return dtString

  of nkSistema:
    n.typ = dtString
    return dtString

  of nkTecla, nkMando:
    # Con clave (Tecla "a" / Mando "verde") = sondeo bool; solo = texto
    if n.strVal.len > 0:
      n.typ = dtBool
      n.intWidth = 8
      return dtBool
    n.typ = dtString
    return dtString

  of nkBool:
    n.typ = dtBool
    n.intWidth = 8
    return dtBool

  of nkDelta, nkTiempo:
    n.typ = dtFloat
    return dtFloat

  of nkAzar:
    discard ctx.analyzeExpr(n.left)
    n.typ = dtInt
    n.intWidth = 32
    return dtInt

  of nkLeeCasilla:
    discard ctx.analyzeExpr(n.left)
    discard ctx.analyzeExpr(n.right)
    n.typ = dtString
    return dtString

  of nkIdent:
    let (found, sym) = ctx.currentScope.findSym(n.identName)
    if found:
      n.typ = sym.typ
      n.intWidth = sym.intWidth
      return sym.typ
    else:
      # Si no está declarada, asumimos int/i32 por defecto y la declaramos
      let sk = if ctx.inFunction: skLocalVar else: skGlobalVar
      let newSym = Symbol(name: n.identName, kind: sk, typ: dtInt, intWidth: 32)
      discard ctx.currentScope.declareSym(newSym)
      n.typ = dtInt
      n.intWidth = 32
      return dtInt

  of nkBinaryOp:
    let tLeft = ctx.analyzeExpr(n.left)
    let tRight = ctx.analyzeExpr(n.right)
    if n.strVal in ["mas", "menos", "por", "entre"] and
       (tLeft == dtString or tRight == dtString):
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "aritmetica con texto no existe (usa mostrar para juntar)",
                           hint: "convierte a numero o trabaja el texto aparte"))

    if n.strVal in ["es_igual_a", "igual", "es_equivalente_a", "es_mayor_que", "es_menor_que", "es_distinto_de", "es_mayor_o_igual", "es_menor_o_igual", "y", "o"]:
      n.typ = dtBool
      n.intWidth = 8
      return dtBool

    # Si es división ('entre'), siempre es float según COMA.txt regla 3
    if n.strVal == "entre":
      n.typ = dtFloat
      return dtFloat

    if tLeft == dtFloat or tRight == dtFloat:
      n.typ = dtFloat
      return dtFloat

    n.typ = dtInt
    n.intWidth = max(n.left.intWidth, n.right.intWidth)
    if n.intWidth < 32: n.intWidth = 32 # evitar desbordamientos comunes en operaciones
    return dtInt

  of nkUnaryOp:
    let subT = ctx.analyzeExpr(n.left)
    if n.strVal == "no":
      n.typ = dtBool
      n.intWidth = 8
      return dtBool
    n.typ = subT
    n.intWidth = n.left.intWidth
    return subT

  of nkCall:
    var argTyps: seq[DataTypeKind] = @[]
    for arg in n.args:
      argTyps.add(ctx.analyzeExpr(arg))
    let (ffound, fsym) = ctx.currentScope.findSym(n.funcName)
    if not ffound or fsym.kind != skFunc:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E003", level: eError,
                           msg: "funcion desconocida: " & n.funcName, hint: "declarala o revisa el nombre"))
      n.typ = dtInt
      n.intWidth = 32
      return dtInt
    if n.args.len != fsym.params.len:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: n.funcName & " quiere " & $fsym.params.len & " argumentos y le das " & $n.args.len,
                           hint: "cuenta los parametros"))
      n.typ = fsym.typ
      n.intWidth = 32
      return fsym.typ
    for i, a in n.args:
      let want = if i < fsym.paramTyps.len: fsym.paramTyps[i] else: dtInt
      let got = argTyps[i]
      var ok = want == got or got == dtUnknown or
               (want == dtInt and got in {dtInt, dtBool}) or
               (want == dtFloat and got in {dtInt, dtFloat, dtBool})
      if want in {dtList, dtListStr, dtListList}:
        # Listas solo por variable o elemento (un literal no tiene dónde materializarse).
        ok = got == want and a.kind in {nkIdent, nkListAccess}
      if not ok:
        ctx.issues.add(Issue(line: a.line, col: a.col, code: "E202", level: eError,
                             msg: n.funcName & " quiere " & tipoHumano(want) & " y le das " & tipoHumano(got),
                             hint: "convierte antes o cambia la firma"))
    n.typ = fsym.typ
    n.intWidth = 32
    return fsym.typ

  of nkListRecordLit:
    # Bloque `G igual lista de registros:` + renglones `registro ...`.
    var okRec = n.children.len > 0
    for row in n.children:
      if row == nil or row.kind != nkRecordLit:
        okRec = false
        break
      for f in row.fields:
        let ft = ctx.analyzeExpr(f.val)
        if ft notin {dtInt, dtBool, dtUnknown}:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "campos de texto aun no en listas de registros",
                               hint: "deja los campos en enteros"))
          okRec = false
          break
    if okRec:
      n.typ = dtListRecord
      return dtListRecord
    n.typ = dtList
    return dtList

  of nkListLit:
    if n.children.len == 0:
      # `vacia` no decide clase: la manda el primer uso (Agregar la adopta).
      n.typ = dtUnknown
      return dtUnknown
    var nTexto = 0
    var nNum = 0
    var nLista = 0
    var nListaTexto = 0
    var nRec = 0
    for child in n.children:
      let t = ctx.analyzeExpr(child)
      if t == dtString: inc nTexto
      elif t in {dtInt, dtFloat, dtBool}: inc nNum
      elif t == dtList: inc nLista
      elif t == dtListStr: inc nListaTexto
      elif t == dtRecord: inc nRec
    if nListaTexto > 0:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "listas de texto aun no se anidan",
                           hint: "anida listas de enteros o usa registros"))
    elif nRec > 0 and (nTexto + nNum + nLista + nListaTexto) > 0:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no mezcles registros con otra cosa",
                           hint: "una fila de registros por elemento"))
    elif nTexto > 0 and (nNum + nLista) > 0:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no mezcles texto con numeros en la misma lista",
                           hint: "una lista es de enteros o de texto, no de las dos"))
    elif nLista > 0 and (nTexto + nNum) > 0:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no mezcles listas con numeros sueltos",
                           hint: "una fila por elemento: lista de listas"))
    if nRec > 0 and nTexto == 0 and nNum == 0 and nLista == 0 and nListaTexto == 0:
      # Campos no enteros en filas: E202 honesto (las filas son de enteros).
      for child in n.children:
        let t = ctx.analyzeExpr(child)
        if t == dtRecord and child.kind == nkRecordLit:
          for f in child.fields:
            let ft = ctx.analyzeExpr(f.val)
            if ft notin {dtInt, dtBool, dtUnknown}:
              ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                                   msg: "campos de texto aun no en listas de registros",
                                   hint: "deja los campos en enteros"))
              break
      n.typ = dtListRecord
      return dtListRecord
    if nTexto > 0 and nNum == 0 and nLista == 0 and nListaTexto == 0 and nRec == 0:
      n.typ = dtListStr
      return dtListStr
    if nLista > 0 and nTexto == 0 and nNum == 0 and nListaTexto == 0 and nRec == 0:
      n.typ = dtListList
      return dtListList
    n.typ = dtList
    return dtList

  of nkRecordLit:
    for f in n.fields:
      discard ctx.analyzeExpr(f.val)
    n.typ = dtRecord
    return dtRecord

  of nkListAccess:
    discard ctx.analyzeExpr(n.left)
    if n.right != nil:
      discard ctx.analyzeExpr(n.right)
    if n.strVal == "longitud":
      n.typ = dtInt
      n.intWidth = 32
      return dtInt
    if n.left != nil and n.left.kind != nkIdent:
      # Acceso sobre valor-lista (Elemento 1 de Elemento 2 de M): manda su tipo.
      if n.left.typ == dtListStr:
        n.typ = dtString
        return dtString
      if n.left.typ == dtListList:
        n.typ = dtList
        return dtList
      if n.left.typ == dtList:
        n.typ = dtInt
        n.intWidth = 32
        return dtInt
    if ctx.listKindOf(n.left) == dtListStr:
      n.typ = dtString
      return dtString
    if ctx.listKindOf(n.left) == dtListList:
      n.typ = dtList
      return dtList
    if ctx.listKindOf(n.left) == dtListRecord:
      # Renglón de lista de registros (solo vive dentro de Campo de ...).
      n.typ = dtRecord
      return dtRecord
    n.typ = dtInt
    n.intWidth = 32
    return dtInt

  of nkFieldAccess:
    # dtUnknown a propósito: el tipo real lo sabe codegen (primera escritura).
    # Así `X igual Nombre_de_J` adopta texto en vez de truncar un puntero.
    discard ctx.analyzeExpr(n.left)
    let rl = ctx.recFieldList(n.left)
    if rl != "":
      let (rfound, rsym) = ctx.currentScope.findSym(rl)
      if rfound and rsym.typ == dtListRecord and n.strVal notin rsym.fields:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E005", level: eError,
                             msg: "el campo " & n.strVal & " no existe en la lista",
                             hint: "campos: " & rsym.fields.join(", ")))
    n.typ = dtUnknown
    n.intWidth = 0
    return dtUnknown

  else:
    return dtVoid

# Análisis de sentencias y bloques
proc analyzeStmt*(ctx: var SemaContext, n: Node) =
  if n == nil: return

  case n.kind
  of nkAssign:
    let t = ctx.analyzeExpr(n.left)
    # El renglón suelto no se asigna (E201 honesto): se lee campo por campo.
    if n.left != nil and n.left.kind == nkListAccess and t == dtRecord:
      let ll = n.left.left
      if ll != nil and ll.kind == nkIdent:
        let (ffound, fsym) = ctx.currentScope.findSym(ll.identName)
        if ffound and fsym.typ == dtListRecord:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "el renglon suelto no se asigna entero",
                               hint: "lee campo por campo: Vida de elemento 1 de G."))
          return
    # Fase 1: las locales ya son tipadas (entero/decimal/texto caben en alloca).
    # Las listas de registros son entidades globales como los registros.
    let toGlobal = t == dtListRecord
    let (found, sym) = ctx.currentScope.findSym(n.identName)
    if not found:
      let sk = if toGlobal: skGlobalVar
               elif ctx.inFunction: skLocalVar else: skGlobalVar
      var newSym = Symbol(name: n.identName, kind: sk, typ: t, intWidth: max(32, n.left.intWidth))
      if t == dtRecord and n.left.kind == nkRecordLit:
        var fNames: seq[string] = @[]
        for f in n.left.fields:
          fNames.add(f.name)
        newSym.fields = fNames
      if t == dtListRecord and (n.left.kind == nkListLit or n.left.kind == nkListRecordLit):
        newSym.fields = ctx.recordListFields(n.left)
      elif t == dtListRecord and n.left.kind == nkIdent:
        let (sfound, ssym) = ctx.currentScope.findSym(n.left.identName)
        if sfound and ssym.typ == dtListRecord:
          newSym.fields = ssym.fields
      if toGlobal:
        discard ctx.globalScope.declareSym(newSym)
      else:
        discard ctx.currentScope.declareSym(newSym)
    else:
      # Actualizar tipo si era desconocido (las listas de registros migran
      # a global: nunca viven en ámbito de función).
      if sym.typ == dtUnknown:
        if t == dtListRecord:
          let (gfound, gsym) = ctx.globalScope.findSym(n.identName)
          if gfound and gsym.typ notin {dtUnknown, dtListRecord}:
            ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                                 msg: n.identName & " era " & tipoHumano(gsym.typ) & " y le das " & tipoHumano(t),
                                 hint: "usa otra variable o convierte antes"))
            return
          ctx.currentScope.symbols.del(n.identName)
          var moved = sym
          moved.typ = t
          moved.kind = skGlobalVar
          if n.left.kind == nkListLit or n.left.kind == nkListRecordLit:
            moved.fields = ctx.recordListFields(n.left)
          elif n.left.kind == nkIdent:
            let (sfound, ssym) = ctx.currentScope.findSym(n.left.identName)
            if sfound and ssym.typ == dtListRecord:
              moved.fields = ssym.fields
          if gfound:
            ctx.globalScope.symbols[n.identName] = moved
          else:
            discard ctx.globalScope.declareSym(moved)
        else:
          var updated = sym
          updated.typ = t
          ctx.currentScope.symbols[n.identName] = updated
      elif sym.typ == dtListRecord and t == dtListRecord:
        if n.left.kind == nkListLit or n.left.kind == nkListRecordLit:
          var updated = sym
          updated.fields = ctx.recordListFields(n.left)
          ctx.globalScope.symbols[n.identName] = updated
        elif n.left.kind == nkIdent:
          let (sfound, ssym) = ctx.currentScope.findSym(n.left.identName)
          if sfound and ssym.typ == dtListRecord:
            var updated = sym
            updated.fields = ssym.fields
            ctx.globalScope.symbols[n.identName] = updated
      else:
        # Cambio de tipo decidido (era ABIERTO): lo numérico mezcla en
        # silencio; lo demás es E202 honesto en vez de IR roto.
        let numA = sym.typ in {dtInt, dtFloat, dtBool}
        let numB = t in {dtInt, dtFloat, dtBool}
        let contA = sym.typ in {dtList, dtListStr, dtListList, dtListRecord, dtRecord}
        let contB = t in {dtList, dtListStr, dtListList, dtListRecord, dtRecord}
        let clash = (numA != numB) or
                    (contA and t notin {dtList, dtListStr, dtListList, dtListRecord, dtRecord, dtUnknown, dtVoid} and sym.typ != t) or
                    (contB and sym.typ notin {dtList, dtListStr, dtListList, dtListRecord, dtRecord} and sym.typ != t) or
                    (contA and contB and sym.typ != t) or
                    (t == dtVoid)
        if clash:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: n.identName & " era " & tipoHumano(sym.typ) & " y le das " & tipoHumano(t),
                               hint: "usa otra variable o convierte antes"))

  of nkFieldAssign:
    discard ctx.analyzeExpr(n.left)
    let tr = ctx.analyzeExpr(n.right)
    let rl = ctx.recFieldList(n.left)
    if rl != "":
      let (rfound, rsym) = ctx.currentScope.findSym(rl)
      if rfound and rsym.typ == dtListRecord:
        if n.strVal notin rsym.fields:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E005", level: eError,
                               msg: "el campo " & n.strVal & " no existe en la lista",
                               hint: "campos: " & rsym.fields.join(", ")))
        elif tr in {dtString, dtFloat}:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "los campos de lista de registros son enteros",
                               hint: "guarda el texto en un registro suelto"))

  of nkListAssign:
    discard ctx.analyzeExpr(n.left)
    if n.right != nil:
      discard ctx.analyzeExpr(n.right)
    let tv = ctx.analyzeExpr(n.target)
    let lk = ctx.listKindOf(n.left)
    if lk == dtListRecord:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "las filas no se reemplazan enteras",
                           hint: "escribe campo por campo: Vida de elemento 1 de G igual 99."))
    elif (lk == dtListStr and tv in {dtInt, dtFloat, dtBool}) or
       (lk == dtList and tv in {dtString, dtList, dtListStr, dtListList, dtRecord}) or
       (lk == dtListList and tv != dtList and tv != dtUnknown):
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "ese valor no cabe en " & tipoHumano(lk),
                           hint: "a lista de texto, texto; a lista de enteros, numeros; a lista de listas, una fila"))

  of nkMostrar:
    for item in n.children:
      let t = ctx.analyzeExpr(item)
      if t == dtListRecord:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "las listas de registros se muestran campo por campo",
                             hint: "muestra Vida de elemento 1 de G."))
      elif t == dtRecord and item.kind == nkListAccess:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "el renglon suelto no se muestra entero",
                             hint: "muestra campo por campo: Vida de elemento 1 de G."))

  of nkPedir:
    let (found, fsym) = ctx.currentScope.findSym(n.identName)
    if not found:
      let newSym = Symbol(name: n.identName, kind: skGlobalVar, typ: dtString)
      discard ctx.currentScope.declareSym(newSym)
    elif fsym.typ in {dtList, dtListStr, dtListList, dtListRecord, dtRecord}:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "pedir no cabe en " & tipoHumano(fsym.typ),
                           hint: "pide a un entero, decimal o texto"))

  of nkLeerLinea:
    # Igual que pedir (declara texto si es nueva).
    let (lfound, lfsym) = ctx.currentScope.findSym(n.identName)
    if not lfound:
      let newSym = Symbol(name: n.identName, kind: skGlobalVar, typ: dtString)
      discard ctx.currentScope.declareSym(newSym)
    elif lfsym.typ in {dtList, dtListStr, dtListList, dtListRecord, dtRecord}:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "leer no cabe en " & tipoHumano(lfsym.typ),
                           hint: "lee a un texto"))

  of nkEscribir:
    let t = ctx.analyzeExpr(n.left)
    if t in {dtList, dtListStr, dtListList, dtListRecord, dtRecord}:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "escribir " & tipoHumano(t) & " no existe aún",
                           hint: "escribe entero, decimal o texto"))

  of nkArchivo:
    if n.left != nil:
      let t = ctx.analyzeExpr(n.left)
      if t != dtString and t != dtUnknown:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "la ruta es texto",
                             hint: "ponla entre comillas o en variable"))

  of nkRed:
    if n.strVal == "conectar":
      if n.left != nil:
        let t = ctx.analyzeExpr(n.left)
        if t != dtString and t != dtUnknown:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "el host es texto",
                               hint: "ponlo entre comillas o en variable"))
      if n.right != nil:
        discard ctx.analyzeExpr(n.right)
    elif n.strVal == "enviar":
      if n.left != nil:
        let t = ctx.analyzeExpr(n.left)
        if t in {dtList, dtListStr, dtListList, dtListRecord, dtRecord}:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "enviar " & tipoHumano(t) & " no existe aún",
                               hint: "envia entero, decimal o texto"))
    elif n.strVal == "recibir":
      let (found, fsym) = ctx.currentScope.findSym(n.identName)
      if not found:
        let newSym = Symbol(name: n.identName, kind: skGlobalVar, typ: dtString)
        discard ctx.currentScope.declareSym(newSym)
      elif fsym.typ in {dtList, dtListStr, dtListList, dtListRecord, dtRecord}:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "recibir no cabe en " & tipoHumano(fsym.typ),
                             hint: "recibe a un texto"))

  of nkPisa:
    discard ctx.analyzeExpr(n.left)

  of nkIf:
    discard ctx.analyzeExpr(n.cond)
    ctx.analyzeStmt(n.thenBlock)
    if n.elseBlock != nil:
      ctx.analyzeStmt(n.elseBlock)

  of nkWhile:
    discard ctx.analyzeExpr(n.cond)
    ctx.analyzeStmt(n.thenBlock)

  of nkTick:
    ctx.analyzeStmt(n.thenBlock)

  of nkMatch:
    discard ctx.analyzeExpr(n.cond)
    for branch in n.children:
      for val in branch.children:
        discard ctx.analyzeExpr(val)
      ctx.analyzeStmt(branch.thenBlock)
    if n.elseBlock != nil:
      ctx.analyzeStmt(n.elseBlock)

  of nkForEach:
    discard ctx.analyzeExpr(n.left)
    let lkf = ctx.listKindOf(n.left)
    # Sobre lista de registros el iterador es la POSICIÓN (entero, v0.4).
    let iterTyp = if lkf == dtListStr: dtString elif lkf == dtListList: dtList else: dtInt
    let (ifound, isym) = ctx.currentScope.findSym(n.identName)
    if not ifound:
      discard ctx.currentScope.declareSym(Symbol(name: n.identName, kind: skLocalVar, typ: iterTyp, intWidth: 32))
    elif isym.typ == dtUnknown:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: n.identName & " aun no tiene clase, usa otro nombre para recorrer",
                           hint: "el que recorre adopta la clase de la lista"))
    elif isym.typ != iterTyp:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: n.identName & " ya existe con otra clase, usa otro nombre para recorrer",
                           hint: "el que recorre adopta la clase de la lista"))
    # Sobre registros el iterador es posición: se recuerda (iterador, lista).
    if lkf == dtListRecord and n.left != nil and n.left.kind == nkIdent:
      ctx.recLoops.add((n.identName, n.left.identName))
      ctx.analyzeStmt(n.thenBlock)
      discard ctx.recLoops.pop()
    else:
      ctx.analyzeStmt(n.thenBlock)
    return

  of nkFuncDecl:
    let oldFn = ctx.currentFunc
    let oldInFn = ctx.inFunction
    ctx.currentFunc = n.funcName
    ctx.inFunction = true
    let funcScope = newScope(ctx.globalScope)
    ctx.currentScope = funcScope
    for i, p in n.params:
      let pt = if i < n.paramTyps.len: n.paramTyps[i] else: dtInt
      if pt == dtRecord:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "registros aún no cruzan a funciones",
                             hint: "pasa campos sueltos o usa global"))
      let pSym = Symbol(name: p, kind: skLocalVar, typ: pt, intWidth: 32)
      discard funcScope.declareSym(pSym)
    ctx.analyzeStmt(n.thenBlock)
    ctx.currentScope = ctx.globalScope
    ctx.inFunction = oldInFn
    ctx.currentFunc = oldFn

  of nkBlock, nkComprobar:
    for s in n.children:
      ctx.analyzeStmt(s)

  of nkExprStmt:
    discard ctx.analyzeExpr(n.left)

  of nkDevolver:
    let t = ctx.analyzeExpr(n.left)
    if t == dtRecord:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "devolver " & tipoHumano(t) & " no cabe en v1",
                           hint: "devuelve entero, decimal o texto"))
    elif ctx.inFunction:
      let (ffound, fsym) = ctx.globalScope.findSym(ctx.currentFunc)
      if ffound and fsym.kind == skFunc:
        let want = fsym.typ
        let clash = (want == dtString and t != dtString) or
                    (want != dtString and t == dtString) or
                    (want in {dtList, dtListStr, dtListList} and t != want)
        if clash:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "esta funcion devuelve " & tipoHumano(want) & " y le das " & tipoHumano(t),
                               hint: "unifica los devolver"))

  of nkLienzo:
    discard ctx.analyzeExpr(n.left)
    discard ctx.analyzeExpr(n.right)

  of nkMarca:
    discard ctx.analyzeExpr(n.left)
    discard ctx.analyzeExpr(n.right)
    if n.target != nil:
      discard ctx.analyzeExpr(n.target)

  of nkTablero:
    discard ctx.analyzeExpr(n.left)
    discard ctx.analyzeExpr(n.right)
    if n.target != nil:
      discard ctx.analyzeExpr(n.target)

  of nkListAdd, nkListRemove:
    discard ctx.analyzeExpr(n.left)
    let rv = ctx.analyzeExpr(n.right)
    # Quitar por posición (primero/ultimo/elemento) no trae valor: solo índice.
    if n.kind == nkListAdd or n.strVal notin ["primero", "ultimo", "elemento"]:
      # `vacia` adopta la clase del primer valor agregado (fuera de funciones;
      # dentro, crea la lista con su primer texto en vez de vacia).
      if n.left != nil and n.left.kind == nkIdent:
        let (lfound, lsym) = ctx.currentScope.findSym(n.left.identName)
        if not lfound:
          # Siempre global (como pedir): codegen materializa listas sueltas
          # en global y así sema y codegen ven la misma clase.
          let nk = if rv == dtString: dtListStr else: dtList
          discard ctx.globalScope.declareSym(Symbol(name: n.left.identName, kind: skGlobalVar, typ: nk, intWidth: 32))
        elif lsym.typ == dtUnknown and not ctx.inFunction:
          var upd = lsym
          upd.typ = if rv == dtString: dtListStr else: dtList
          ctx.currentScope.symbols[n.left.identName] = upd
      let lk2 = ctx.listKindOf(n.left)
      if lk2 == dtListRecord:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "en listas de registros no se agrega ni se quita",
                             hint: "se construyen de una vez: G igual lista J1 y J2."))
      elif lk2 == dtListStr and rv in {dtInt, dtFloat, dtBool}:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "ese valor no cabe en lista de texto",
                             hint: "a lista de texto, texto entre comillas"))
      elif lk2 == dtListList and rv != dtList and rv != dtUnknown:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "ese valor no cabe en lista de listas",
                             hint: "agrega una fila entera (una lista)"))
      elif lk2 == dtList and rv in {dtString, dtList, dtListStr, dtListList, dtRecord}:
        # `vacia` sin clase dentro de funciones: pide literal con texto.
        let (ffound, fsym) = ctx.currentScope.findSym(n.left.identName)
        if rv == dtString and ffound and fsym.typ == dtUnknown and ctx.inFunction:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "en funciones crea la lista con su primer texto",
                               hint: "escribe L igual lista \"a\" y \"b\"."))
        elif not (ffound and fsym.typ == dtUnknown):
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "ese valor no cabe en lista",
                               hint: "a lista de enteros, numeros"))

  of nkPointerDecl:
    let ptrSym = Symbol(name: n.identName, kind: skPointer, targetVar: n.strVal)
    discard ctx.currentScope.declareSym(ptrSym)

  of nkCall:
    # Llamada suelta: se analiza igual (aridad, tipos) y se descarta el retorno.
    discard ctx.analyzeExpr(n)

  else:
    discard

proc analyzeSemantics*(root: Node, issues: var seq[Issue]): SemaContext =
  var ctx = newSemaContext()
  ctx.preScanDeclarations(root)
  ctx.inferReturns(root)
  for stmt in root.children:
    ctx.analyzeStmt(stmt)
  issues.add(ctx.issues)
  return ctx
