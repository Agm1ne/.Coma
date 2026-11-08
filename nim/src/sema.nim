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
  of dtRecord: "registro"
  of dtHandle: "asa"
  else: "valor"

proc newSemaContext*(): SemaContext =
  result.globalScope = newScope()
  result.currentScope = result.globalScope
  result.issues = @[]
  result.inFunction = false
  result.currentFunc = ""

proc listKindOf(ctx: SemaContext, n: Node): DataTypeKind =
  ## Clase real de la lista nombrada (dtList por defecto si no se sabe).
  if n != nil and n.kind == nkIdent:
    let (found, sym) = ctx.currentScope.findSym(n.identName)
    if found and sym.typ in {dtList, dtListStr, dtListList}:
      return sym.typ
  return dtList

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
    # Declarar funciones anidadas tambien (capturas de entorno / closures).
    preScanDeclarations(ctx, root.thenBlock)
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
    # Si hay `como <tipo>` declarado, respetarlo en vez de inferir.
    if root.hasRetTyp:
      let (ff, fsym) = ctx.globalScope.findSym(root.funcName)
      if ff and fsym.kind == skFunc:
        var upd = fsym
        upd.typ = root.typ
        ctx.globalScope.symbols[root.funcName] = upd
      return
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
    let at = ctx.analyzeExpr(n.left)
    if at == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "azar no acepta asa/nula como maximo",
                           hint: "pasa un numero entero"))
    n.typ = dtInt
    n.intWidth = 32
    return dtInt

  of nkLeeCasilla:
    discard ctx.analyzeExpr(n.left)
    discard ctx.analyzeExpr(n.right)
    n.typ = dtString
    return dtString

  of nkIdent:
    # 'nula' / 'null' / 'nil' / 'none' = asa nulo (FFI). No se declara como variable.
    if n.identName == "nula":
      n.typ = dtHandle
      n.intWidth = 0
      return dtHandle
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
       (tLeft == dtString or tRight == dtString or tLeft == dtHandle or tRight == dtHandle):
      let badT = if tLeft == dtHandle: dtHandle elif tRight == dtHandle: dtHandle else: dtString
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "aritmetica con " & tipoHumano(badT) & " no existe",
                           hint: "usa numeros o textos, no asas/nulas"))

    if n.strVal in ["es_igual_a", "igual", "es_equivalente_a", "es_mayor_que", "es_menor_que", "es_distinto_de", "es_mayor_o_igual", "es_menor_o_igual", "y", "o"]:
      if tLeft == dtHandle or tRight == dtHandle:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "no se puede comparar asa/nula",
                             hint: "compara enteros, decimales o textos"))
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
    if n.strVal == "menos" and subT == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "menos unario no acepta asa/nula",
                           hint: "usa un numero"))
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

  of nkListLit:
    if n.children.len == 0:
      # `vacia` no decide clase: la manda el primer uso (Agregar la adopta).
      n.typ = dtUnknown
      return dtUnknown
    var nTexto = 0
    var nNum = 0
    var nLista = 0
    var nListaTexto = 0
    for child in n.children:
      let t = ctx.analyzeExpr(child)
      if t == dtHandle:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "no se puede poner asa/nula en una lista",
                             hint: "usa enteros, decimales o textos"))
      elif t == dtString: inc nTexto
      elif t in {dtInt, dtFloat, dtBool}: inc nNum
      elif t == dtList: inc nLista
      elif t == dtListStr: inc nListaTexto
    if nListaTexto > 0:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "listas de texto aun no se anidan",
                           hint: "anida listas de enteros o usa registros"))
    elif nTexto > 0 and (nNum + nLista) > 0:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no mezcles texto con numeros en la misma lista",
                           hint: "una lista es de enteros o de texto, no de las dos"))
    elif nLista > 0 and (nTexto + nNum) > 0:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no mezcles listas con numeros sueltos",
                           hint: "una fila por elemento: lista de listas"))
    if nTexto > 0 and nNum == 0 and nLista == 0 and nListaTexto == 0:
      n.typ = dtListStr
      return dtListStr
    if nLista > 0 and nTexto == 0 and nNum == 0 and nListaTexto == 0:
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
    let lalt = ctx.analyzeExpr(n.left)
    if lalt == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no se puede indexar una asa/nula",
                           hint: "indexa una lista"))
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
    n.typ = dtInt
    n.intWidth = 32
    return dtInt

  of nkFieldAccess:
    # dtUnknown a propósito: el tipo real lo sabe codegen (primera escritura).
    # Así `X igual Nombre_de_J` adopta texto en vez de truncar un puntero.
    let lt = ctx.analyzeExpr(n.left)
    if lt == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no se puede leer campo de una asa/nula",
                           hint: "usa un registro o variable normal"))
    n.typ = dtUnknown
    n.intWidth = 0
    return dtUnknown

  else:
    return dtVoid

proc collectFreeVars(ctx: var SemaContext, body: Node, params: seq[string],
                     defined: var Table[string, bool], result: var Table[string, bool]) =
  ## Recolecta identificadores usados en `body` que no son parámetros,
  ## no se declaran en el cuerpo, no son globales ni nombres de función.
  ## Esos son candidatos a captura del entorno (closure).
  if body == nil: return
  case body.kind
  of nkIdent:
    if not params.contains(body.identName) and not defined.hasKey(body.identName):
      let (gfound, gsym) = ctx.globalScope.findSym(body.identName)
      if not gfound or gsym.kind != skFunc:
        result[body.identName] = true
  of nkAssign:
    defined[body.identName] = true
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkForEach:
    defined[body.identName] = true
    collectFreeVars(ctx, body.left, params, defined, result)
    collectFreeVars(ctx, body.thenBlock, params, defined, result)
  of nkPedir, nkLeerLinea:
    defined[body.identName] = true
  of nkRed:
    if body.strVal == "recibir": defined[body.identName] = true
    collectFreeVars(ctx, body.left, params, defined, result)
    collectFreeVars(ctx, body.right, params, defined, result)
  of nkFieldAssign:
    collectFreeVars(ctx, body.left, params, defined, result)
    collectFreeVars(ctx, body.right, params, defined, result)
  of nkListAssign:
    collectFreeVars(ctx, body.left, params, defined, result)
    collectFreeVars(ctx, body.right, params, defined, result)
    collectFreeVars(ctx, body.target, params, defined, result)
  of nkMostrar:
    for it in body.children: collectFreeVars(ctx, it, params, defined, result)
  of nkEscribir:
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkPisa:
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkIf:
    collectFreeVars(ctx, body.cond, params, defined, result)
    collectFreeVars(ctx, body.thenBlock, params, defined, result)
    if body.elseBlock != nil and body.elseBlock.kind in {nkBlock, nkIf}:
      collectFreeVars(ctx, body.elseBlock, params, defined, result)
  of nkWhile, nkTick:
    collectFreeVars(ctx, body.cond, params, defined, result)
    collectFreeVars(ctx, body.thenBlock, params, defined, result)
  of nkMatch:
    collectFreeVars(ctx, body.cond, params, defined, result)
    for br in body.children: collectFreeVars(ctx, br.thenBlock, params, defined, result)
    if body.elseBlock != nil: collectFreeVars(ctx, body.elseBlock, params, defined, result)
  of nkBlock, nkComprobar:
    for s in body.children: collectFreeVars(ctx, s, params, defined, result)
  of nkExprStmt:
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkDevolver:
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkCall:
    for a in body.args: collectFreeVars(ctx, a, params, defined, result)
  of nkFieldAccess:
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkListAccess:
    collectFreeVars(ctx, body.left, params, defined, result)
    collectFreeVars(ctx, body.right, params, defined, result)
  of nkListLit:
    for ch in body.children: collectFreeVars(ctx, ch, params, defined, result)
  of nkRecordLit:
    for f in body.fields: collectFreeVars(ctx, f.val, params, defined, result)
  of nkUnaryOp:
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkBinaryOp:
    collectFreeVars(ctx, body.left, params, defined, result)
    collectFreeVars(ctx, body.right, params, defined, result)
  of nkAzar:
    collectFreeVars(ctx, body.left, params, defined, result)
  of nkLeeCasilla:
    collectFreeVars(ctx, body.left, params, defined, result)
    collectFreeVars(ctx, body.right, params, defined, result)
  else: discard

# Análisis de sentencias y bloques
proc analyzeStmt*(ctx: var SemaContext, n: Node) =
  if n == nil: return

  case n.kind
  of nkAssign:
    let t = ctx.analyzeExpr(n.left)
    # Fase 1: las locales ya son tipadas (entero/decimal/texto caben en alloca).
    let (found, sym) = ctx.currentScope.findSym(n.identName)
    if not found:
      # 'nula' solo puede ir en una variable de asa (puntero).
      if t == dtHandle:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "no puedes asignar nula a una variable comun",
                             hint: "declara la variable con 'puntero' o usa otro tipo"))
      let sk = if ctx.inFunction: skLocalVar else: skGlobalVar
      var newSym = Symbol(name: n.identName, kind: sk, typ: t, intWidth: max(32, n.left.intWidth))
      if t == dtRecord and n.left.kind == nkRecordLit:
        var fNames: seq[string] = @[]
        for f in n.left.fields:
          fNames.add(f.name)
        newSym.fields = fNames
      discard ctx.currentScope.declareSym(newSym)
    else:
      # Actualizar tipo si era desconocido
      if sym.typ == dtUnknown:
        var updated = sym
        updated.typ = t
        ctx.currentScope.symbols[n.identName] = updated
      else:
        # Cambio de tipo decidido (era ABIERTO): lo numérico mezcla en
        # silencio; lo demás es E202 honesto en vez de IR roto.
        let numA = sym.typ in {dtInt, dtFloat, dtBool}
        let numB = t in {dtInt, dtFloat, dtBool}
        let contA = sym.typ in {dtList, dtListStr, dtListList, dtRecord}
        let contB = t in {dtList, dtListStr, dtListList, dtRecord}
        let isHandleA = sym.typ == dtHandle
        let isHandleB = t == dtHandle
        let clash = (numA != numB) or
                    (contA and t notin {dtList, dtListStr, dtListList, dtRecord, dtUnknown, dtVoid} and sym.typ != t) or
                    (contB and sym.typ notin {dtList, dtListStr, dtListList, dtRecord} and sym.typ != t) or
                    (contA and contB and sym.typ != t) or
                    (t == dtVoid) or
                    (isHandleA != isHandleB)
        if clash:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: n.identName & " era " & tipoHumano(sym.typ) & " y le das " & tipoHumano(t),
                               hint: "usa otra variable o convierte antes"))

  of nkFieldAssign:
    discard ctx.analyzeExpr(n.left)
    discard ctx.analyzeExpr(n.right)

  of nkListAssign:
    discard ctx.analyzeExpr(n.left)
    if n.right != nil:
      discard ctx.analyzeExpr(n.right)
    let tv = ctx.analyzeExpr(n.target)
    let lk = ctx.listKindOf(n.left)
    if (lk == dtListStr and tv in {dtInt, dtFloat, dtBool}) or
       (lk == dtList and tv in {dtString, dtList, dtListStr, dtListList, dtRecord}) or
       (lk == dtListList and tv != dtList and tv != dtUnknown):
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "ese valor no cabe en " & tipoHumano(lk),
                           hint: "a lista de texto, texto; a lista de enteros, numeros; a lista de listas, una fila"))

  of nkMostrar:
    for item in n.children:
      let it = ctx.analyzeExpr(item)
      if it == dtHandle:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "mostrar no acepta asa/nula",
                             hint: "muestra entero, decimal o texto"))

  of nkPedir:
    let (found, fsym) = ctx.currentScope.findSym(n.identName)
    if not found:
      let newSym = Symbol(name: n.identName, kind: skGlobalVar, typ: dtString)
      discard ctx.currentScope.declareSym(newSym)
    elif fsym.typ in {dtList, dtListStr, dtListList, dtRecord, dtHandle}:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "pedir no cabe en " & tipoHumano(fsym.typ),
                           hint: "pide a un entero, decimal o texto"))

  of nkLeerLinea:
    # Igual que pedir (declara texto si es nueva).
    let (lfound, lfsym) = ctx.currentScope.findSym(n.identName)
    if not lfound:
      let newSym = Symbol(name: n.identName, kind: skGlobalVar, typ: dtString)
      discard ctx.currentScope.declareSym(newSym)
    elif lfsym.typ in {dtList, dtListStr, dtListList, dtRecord, dtHandle}:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "leer no cabe en " & tipoHumano(lfsym.typ),
                           hint: "lee a un texto"))

  of nkEscribir:
    let t = ctx.analyzeExpr(n.left)
    if t in {dtList, dtListStr, dtListList, dtRecord, dtHandle}:
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
        if t in {dtList, dtListStr, dtListList, dtRecord, dtHandle}:
          ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                               msg: "enviar " & tipoHumano(t) & " no existe aún",
                               hint: "envia entero, decimal o texto"))
    elif n.strVal == "recibir":
      let (found, fsym) = ctx.currentScope.findSym(n.identName)
      if not found:
        let newSym = Symbol(name: n.identName, kind: skGlobalVar, typ: dtString)
        discard ctx.currentScope.declareSym(newSym)
      elif fsym.typ in {dtList, dtListStr, dtListList, dtRecord, dtHandle}:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "recibir no cabe en " & tipoHumano(fsym.typ),
                             hint: "recibe a un texto"))

  of nkPisa:
    let pt = ctx.analyzeExpr(n.left)
    if pt == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "pisa no acepta asa/nula",
                           hint: "pisa un entero, decimal o texto"))

  of nkIf:
    let ct = ctx.analyzeExpr(n.cond)
    if ct == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "condicion no acepta asa/nula",
                           hint: "usa una comparacion o booleano"))
    ctx.analyzeStmt(n.thenBlock)
    if n.elseBlock != nil:
      ctx.analyzeStmt(n.elseBlock)

  of nkWhile:
    let wt = ctx.analyzeExpr(n.cond)
    if wt == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "condicion no acepta asa/nula",
                           hint: "usa una comparacion o booleano"))
    ctx.analyzeStmt(n.thenBlock)

  of nkTick:
    ctx.analyzeStmt(n.thenBlock)

  of nkMatch:
    let mt = ctx.analyzeExpr(n.cond)
    if mt == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "según no acepta asa/nula",
                           hint: "usa un entero o texto"))
    for branch in n.children:
      for val in branch.children:
        discard ctx.analyzeExpr(val)
      ctx.analyzeStmt(branch.thenBlock)
    if n.elseBlock != nil:
      ctx.analyzeStmt(n.elseBlock)

  of nkForEach:
    let flt = ctx.analyzeExpr(n.left)
    if flt == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no se puede recorrer una asa/nula",
                           hint: "recorre una lista"))
    let lkf = ctx.listKindOf(n.left)
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

  of nkFuncDecl:
    let oldFn = ctx.currentFunc
    let oldInFn = ctx.inFunction
    ctx.currentFunc = n.funcName
    ctx.inFunction = true
    # Scope de la hija con el scope actual (padre) como padre, para capturar entorno.
    let funcScope = newScope(ctx.currentScope)
    ctx.currentScope = funcScope
    # Recolectar variables libres del cuerpo (candidatas a captura del padre).
    var freeVars = initTable[string, bool]()
    var defined = initTable[string, bool]()
    collectFreeVars(ctx, n.thenBlock, n.params, defined, freeVars)
    var capVars: seq[string] = @[]
    var capTyps: seq[DataTypeKind] = @[]
    for vn in freeVars.keys:
      var vt = dtInt
      if ctx.currentScope.parent != nil and ctx.currentScope.parent.symbols.hasKey(vn):
        vt = ctx.currentScope.parent.symbols[vn].typ
      elif ctx.globalScope.symbols.hasKey(vn):
        vt = ctx.globalScope.symbols[vn].typ
      # Tipos no capturables en v1: lista, registro, asa.
      if vt in {dtList, dtListStr, dtListList, dtRecord, dtListRecord, dtHandle}:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                             msg: "no se puede capturar " & tipoHumano(vt) & " en cierre",
                             hint: "captura solo entero, decimal o texto"))
        continue
      capVars.add(vn)
      capTyps.add(vt)
      discard funcScope.declareSym(Symbol(name: vn, kind: skLocalVar, typ: vt, intWidth: 32))
    n.capturedVars = capVars
    n.capturedTyps = capTyps
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
    elif t == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "devolver asa/nula no existe en v1",
                           hint: "devuelve entero, decimal o texto"))
    elif ctx.inFunction:
      let (ffound, fsym) = ctx.globalScope.findSym(ctx.currentFunc)
      if ffound and fsym.kind == skFunc:
        let want = fsym.typ
        let clash = (want == dtString and t != dtString) or
                    (want != dtString and t == dtString) or
                    (want in {dtList, dtListStr, dtListList} and t != want) or
                    (want == dtHandle and t != dtHandle) or
                    (t == dtHandle and want != dtHandle)
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
    if rv == dtHandle:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no puedes agregar asa/nula a una lista",
                           hint: "agrega enteros, decimales o textos"))
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
      if lk2 == dtListStr and rv in {dtInt, dtFloat, dtBool}:
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
    let ptrSym = Symbol(name: n.identName, kind: skPointer, typ: dtHandle, targetVar: n.strVal)
    discard ctx.currentScope.declareSym(ptrSym)

  of nkDireccion:
    # direccion de X: solo vale si X es una funcion o puntero declarado.
    let (dfound, dsym) = ctx.currentScope.findSym(n.identName)
    if not dfound:
      let (gfound, gsym) = ctx.globalScope.findSym(n.identName)
      if gfound and gsym.kind == skFunc:
        # direccion de una funcion: OK (asa opaca).
        discard
      elif gfound and gsym.kind == skPointer:
        # direccion de un puntero: OK.
        discard
      else:
        ctx.issues.add(Issue(line: n.line, col: n.col, code: "E003", level: eError,
                             msg: "direccion de '" & n.identName & "' desconocida",
                             hint: "declara primero la funcion o el puntero"))
    elif dsym.kind == skPointer:
      # direccion de un puntero local: OK.
      discard
    else:
      ctx.issues.add(Issue(line: n.line, col: n.col, code: "E202", level: eError,
                           msg: "no se puede tomar direccion de '" & n.identName & "' (no es puntero ni funcion)",
                           hint: "usa un puntero o una funcion"))

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
