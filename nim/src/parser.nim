# parser.nim — Parser sintáctico de .Coma
import strutils, tables
import ast

type
  Parser* = object
    tokens*: seq[Token]
    pos*: int
    issues*: seq[Issue]
    funcNames*: seq[string] # firmas pre-escaneadas (llamadas sin args + orden libre)

proc scanFuncNames*(tokens: seq[Token]): seq[string] =
  ## `funcion Nombre` en el flujo (el Nombre va en mayúscula = tokIdent).
  result = @[]
  var i = 0
  while i < tokens.len:
    if tokens[i].kind == tokKeyword and tokens[i].val == "funcion" and
       i + 1 < tokens.len and tokens[i + 1].kind == tokIdent:
      if tokens[i + 1].val notin result:
        result.add(tokens[i + 1].val)
      i += 2
    else:
      inc i

const ComaBuiltins* = ["Agmine"]
  ## Firmas propias del lenguaje (huevo de pascua + utilidades): valen sin
  ## declarar en cualquier archivo y en ambas pasadas del driver.

proc newParser*(tokens: seq[Token], extraFuncs: seq[string] = @[]): Parser =
  result.tokens = tokens
  result.pos = 0
  result.issues = @[]
  result.funcNames = scanFuncNames(tokens)
  for f in extraFuncs:
    if f notin result.funcNames:
      result.funcNames.add(f)
  for b in ComaBuiltins:
    if b notin result.funcNames:
      result.funcNames.add(b)

proc peek(p: Parser, offset = 0): Token =
  let idx = p.pos + offset
  if idx < p.tokens.len:
    return p.tokens[idx]
  return Token(kind: tokEof)

proc advance(p: var Parser): Token =
  if p.pos < p.tokens.len:
    result = p.tokens[p.pos]
    inc p.pos
  else:
    result = Token(kind: tokEof)

proc matchKeyword(p: var Parser, kw: string): bool =
  if p.peek().kind == tokKeyword and p.peek().val == kw:
    discard p.advance()
    return true
  return false

proc expectDot(p: var Parser): bool =
  if p.peek().kind == tokDot:
    discard p.advance()
    return true
  let tok = p.peek()
  p.issues.add(Issue(line: tok.line, col: tok.col, code: "E001", level: eError,
                     msg: "falta el punto final '.' en la sentencia", hint: "agrega '.' al final de la linea"))
  return false

proc isArticle(tok: Token): bool =
  tok.kind == tokKeyword and tok.val in ["el", "la", "los", "las", "un", "una", "unos", "unas", "que", "the", "an"]

proc skipArticles(p: var Parser) =
  while p.peek().kind == tokKeyword and p.peek().val in ["el", "la", "los", "las", "un", "una", "unos", "unas", "que", "the", "an"]:
    discard p.advance()

proc skipArticlesAfterPrep(p: var Parser) =
  # Tras una preposición estructural ya consumida ("de"/"a"/"en"), una "a"/"an"
  # suelta solo puede ser artículo ("append 5 to a Pack"), nunca otra preposición.
  while p.peek().kind == tokKeyword and p.peek().val in ["el", "la", "los", "las", "un", "una", "unos", "unas", "que", "the", "an", "a"]:
    discard p.advance()

proc skipLeadingFiller(p: var Parser) =
  # Relleno humano al inicio de sentencia: "de en caso de que...", "la Vida igual...".
  # "de"/"que"/artículos nunca abren una sentencia válida, así que es seguro saltarlos.
  while p.peek().kind == tokKeyword and p.peek().val in ["de", "que", "el", "la", "los", "las", "un", "una", "unos", "unas", "the", "an"]:
    if p.peek(1).kind == tokEof or p.peek(1).kind == tokDot:
      break
    discard p.advance()

proc esIniciadorDeSentencia(val: string): bool =
  ## Palabras que abren una sentencia estructural: nunca son asignación `X igual Y.`
  val in ["mostrar", "pedir", "abrir", "crear", "eliminar", "cerrar", "lee", "escribir",
          "conectar", "enviar", "recibir", "desconectar", "pisa", "en_caso_de_que",
          "mientras", "tick", "segun", "por_cada", "para", "sigue", "fin", "comprobar",
          "devolver", "esperar", "limpiar", "lienzo", "marca", "muro", "moneda", "meta",
          "tablero", "poner", "agregar", "quitar", "funcion", "traer", "registro",
          "puntero", "gpu", "sino", "otro", "caso", "verdad", "falso", "vacia"]

# Declaración adelantada de expresiones y sentencias
proc parseExpression*(p: var Parser): Node
proc parseComparison*(p: var Parser): Node
proc parseStatement*(p: var Parser): Node
proc parseTypeWord(p: var Parser): DataTypeKind

# Parseo primario (literales, variables, llamadas, accesos)
proc parsePrimary(p: var Parser): Node =
  # Artículos humanos ignorables: "la Vida", "el Heroe", "que 5".
  # Nunca son estructurales aquí, así que se saltan con seguridad.
  if isArticle(p.peek()):
    discard p.advance()
    return p.parsePrimary()
  let tok = p.peek()

  case tok.kind
  of tokInt:
    discard p.advance()
    return Node(kind: nkInt, line: tok.line, col: tok.col, typ: dtInt, intVal: tok.intVal)
  of tokFloat:
    discard p.advance()
    return Node(kind: nkFloat, line: tok.line, col: tok.col, typ: dtFloat, floatVal: tok.floatVal)
  of tokStr:
    discard p.advance()
    return Node(kind: nkStr, line: tok.line, col: tok.col, typ: dtString, strVal: tok.val)
  of tokIdent:
    let idTok = p.advance()
    let name = idTok.val

    # ¿Es llamada a función con argumentos separados por 'y'?
    # Si sigue una expresión válida (y NO está cerrada por un terminador '.')
    if p.peek().kind in {tokInt, tokFloat, tokStr, tokIdent} and p.peek().val notin ["igual", "mas", "menos", "por", "entre", "es_igual_a", "en", "de"]:
      var args: seq[Node] = @[]
      args.add(p.parseComparison())
      while p.matchKeyword("y"):
        args.add(p.parseComparison())
      return Node(kind: nkCall, line: idTok.line, col: idTok.col, funcName: name, args: args)

    # ¿Llamada sin argumentos? Solo si es firma conocida (si no, es variable).
    if name in p.funcNames and p.peek().kind notin {tokInt, tokFloat, tokStr, tokIdent}:
      return Node(kind: nkCall, line: idTok.line, col: idTok.col, funcName: name, args: @[])

    return Node(kind: nkIdent, line: idTok.line, col: idTok.col, identName: name)

  of tokKeyword:
    # Casos especiales de palabras clave como valor
    if tok.val == "verdad":
      discard p.advance()
      return Node(kind: nkBool, line: tok.line, col: tok.col, typ: dtBool, intVal: 1)
    elif tok.val == "falso":
      discard p.advance()
      return Node(kind: nkBool, line: tok.line, col: tok.col, typ: dtBool, intVal: 0)
    elif tok.val in ["tecla", "key"]:
      discard p.advance()
      # Tecla "a" = sondeo directo de esa tecla (vale diagonal).
      # Tecla sola = última tecla en buffer ("" si ninguna).
      if p.peek().kind == tokStr:
        let argTok = p.advance()
        return Node(kind: nkTecla, line: tok.line, col: tok.col, typ: dtBool, strVal: argTok.val.toLowerAscii())
      return Node(kind: nkTecla, line: tok.line, col: tok.col, typ: dtString, strVal: "")
    elif tok.val == "mando":
      discard p.advance()
      # Mando "verde" = botón/traste apretado AHORA (i1). Mando solo = último (texto).
      if p.peek().kind == tokStr:
        let argTok = p.advance()
        return Node(kind: nkMando, line: tok.line, col: tok.col, typ: dtBool, strVal: argTok.val.toLowerAscii())
      return Node(kind: nkMando, line: tok.line, col: tok.col, typ: dtString, strVal: "")
    elif tok.val in ["hora", "fecha", "usuario", "sistema", "version", "directorio"]:
      # Presets del sistema (solo lectura, como Tiempo). Multiplataforma en rt.
      discard p.advance()
      return Node(kind: nkSistema, line: tok.line, col: tok.col, typ: dtString, strVal: tok.val)
    elif tok.val in ["delta", "segundos", "segundo"]:
      discard p.advance()
      return Node(kind: nkDelta, line: tok.line, col: tok.col, typ: dtFloat)
    elif tok.val in ["tiempo", "time"]:
      discard p.advance()
      return Node(kind: nkTiempo, line: tok.line, col: tok.col, typ: dtFloat)
    elif tok.val == "azar":
      discard p.advance()
      let maxNode = p.parseComparison()
      return Node(kind: nkAzar, line: tok.line, col: tok.col, typ: dtInt, left: maxNode)
    elif tok.val in ["nula", "null", "nil", "none"]:
      # Nula de asa (FFI): valor opaco nulo, solo vale para asa/direccion.
      discard p.advance()
      return Node(kind: nkIdent, line: tok.line, col: tok.col, identName: "nula", typ: dtHandle)
    elif tok.val == "lee":
      # Dos sentidos por forma (como `igual` o `add`): lee X y Y = casilla
      # del tablero; leer Linea. (un nombre) = siguiente línea del fichero.
      discard p.advance()
      let xNode = p.parsePrimary()
      if p.matchKeyword("y"):
        let yNode = p.parsePrimary()
        return Node(kind: nkLeeCasilla, line: tok.line, col: tok.col, typ: dtString, left: xNode, right: yNode)
      elif xNode != nil and xNode.kind == nkIdent:
        return Node(kind: nkLeerLinea, line: tok.line, col: tok.col, identName: xNode.identName)
      else:
        p.issues.add(Issue(line: tok.line, col: tok.col, code: "E001", level: eError,
                           msg: "leer quiere variable o casilla X y Y", hint: "abre primero; lee Linea."))
        return nil
    elif tok.val in ["elemento", "primero", "ultimo", "longitud"]:
      # Elemento 2 de L / Primero de L / Ultimo de L / Longitud de L
      # ("Longitud de la Lista" también vale)
      let op = tok.val
      discard p.advance()
      var idxNode: Node = nil
      if op == "elemento":
        idxNode = p.parsePrimary()
      discard p.matchKeyword("de")
      p.skipArticlesAfterPrep()
      let listNode = p.parsePrimary()
      return Node(kind: nkListAccess, line: tok.line, col: tok.col, strVal: op, left: listNode, right: idxNode)
    elif tok.val == "lista":
      # lista 1 y 2 y 3
      discard p.advance()
      var elems: seq[Node] = @[]
      if p.peek().kind notin {tokDot, tokColon, tokEof}:
        elems.add(p.parseComparison())
        while p.matchKeyword("y"):
          elems.add(p.parseComparison())
      return Node(kind: nkListLit, line: tok.line, col: tok.col, typ: dtList, children: elems)
    elif tok.val == "vacia":
      discard p.advance()
      return Node(kind: nkListLit, line: tok.line, col: tok.col, typ: dtList, children: @[])
    elif tok.val == "registro":
      # registro Vida 30 y Ataque 5
      discard p.advance()
      var fields: seq[tuple[name: string, val: Node]] = @[]
      if p.peek().kind == tokIdent or (p.peek().kind == tokKeyword and p.peek(1).kind in {tokInt, tokFloat, tokStr, tokIdent}):
        let fName = if p.peek().kind == tokIdent: p.advance().val else: capitalizeAscii(p.advance().val)
        let fVal = p.parsePrimary()
        fields.add((fName, fVal))
        while p.matchKeyword("y"):
          let nextName = if p.peek().kind == tokIdent: p.advance().val else: capitalizeAscii(p.advance().val)
          let nextVal = p.parsePrimary()
          fields.add((nextName, nextVal))
      return Node(kind: nkRecordLit, line: tok.line, col: tok.col, typ: dtRecord, fields: fields)
    else:
      discard p.advance()
      return Node(kind: nkIdent, line: tok.line, col: tok.col, identName: tok.val)
  else:
    discard p.advance()
    return Node(kind: nkIdent, line: tok.line, col: tok.col, identName: tok.val)

# Expresiones con precedencia:
# 1) Primarias y Unarias (no, menos)
# 2) Multiplicativas (por, entre)
# 3) Aditivas (mas, menos)
# 4) Comparaciones (es_igual_a, igual, es_mayor_que, etc.)
# 5) Lógicas (y, o)

proc parseUnary(p: var Parser): Node =
  let tok = p.peek()
  if tok.kind == tokKeyword and tok.val in ["no", "menos"]:
    discard p.advance()
    let sub = parseUnary(p)
    return Node(kind: nkUnaryOp, line: tok.line, col: tok.col, strVal: tok.val, left: sub)
  return parsePrimary(p)

# Manejo de 'Campo de Registro' y 'Registro.Campo' como expresión primaria/de acceso
proc parseAccessChain(p: var Parser): Node =
  var node = parseUnary(p)
  while true:
    # 'Vida de E' -> nkFieldAccess ('Vida de el Heroe' / 'Vida del Heroe' también valen)
    if p.matchKeyword("de"):
      p.skipArticlesAfterPrep()
      let target = parseUnary(p)
      let fieldName = if node.kind == nkIdent: node.identName else: node.strVal
      node = Node(kind: nkFieldAccess, line: node.line, col: node.col, left: target, strVal: fieldName)
    # 'Heroe.Vida' -> nkFieldAccess (solo si el '.' va pegado a un ident EN LA MISMA LINEA).
    # Si el '.' es terminador de sentencia, el siguiente ident esta en otra linea: NO consumir.
    elif p.peek().kind == tokDot and p.peek(1).kind == tokIdent and
         p.peek().line == p.peek(1).line and p.peek(1).col == p.peek().col + 1:
      discard p.advance() # consume '.'
      let fieldTok = p.advance()
      let recNode = node
      node = Node(kind: nkFieldAccess, line: node.line, col: node.col, left: recNode, strVal: fieldTok.val)
    else:
      break
  return node

proc parseMul(p: var Parser): Node =
  var left = parseAccessChain(p)
  while p.peek().kind == tokKeyword and p.peek().val in ["por", "entre"]:
    let opTok = p.advance()
    let right = parseAccessChain(p)
    left = Node(kind: nkBinaryOp, line: opTok.line, col: opTok.col, strVal: opTok.val, left: left, right: right)
  return left

proc parseAdd(p: var Parser): Node =
  var left = parseMul(p)
  while p.peek().kind == tokKeyword and p.peek().val in ["mas", "menos"]:
    let opTok = p.advance()
    let right = parseMul(p)
    left = Node(kind: nkBinaryOp, line: opTok.line, col: opTok.col, strVal: opTok.val, left: left, right: right)
  return left

proc parseBitwise(p: var Parser): Node =
  var left = parseAdd(p)
  while p.peek().kind == tokKeyword and p.peek().val in ["y_bit", "o_bit", "xor", "desplaza_izquierda", "desplaza_derecha"]:
    let opTok = p.advance()
    let right = parseAdd(p)
    left = Node(kind: nkBinaryOp, line: opTok.line, col: opTok.col, strVal: opTok.val, left: left, right: right)
  return left

proc parseComparison(p: var Parser): Node =
  var left = parseBitwise(p)
  while p.peek().kind == tokKeyword and p.peek().val in ["es_igual_a", "igual", "es_equivalente_a", "es_mayor_que", "es_menor_que", "es_distinto_de", "es_mayor_o_igual", "es_menor_o_igual"]:
    let opTok = p.advance()
    let right = parseBitwise(p)
    left = Node(kind: nkBinaryOp, line: opTok.line, col: opTok.col, strVal: opTok.val, left: left, right: right)
  return left

proc parseLogical(p: var Parser): Node =
  var left = parseComparison(p)
  while p.peek().kind == tokKeyword and p.peek().val in ["y", "o"]:
    let opTok = p.advance()
    let right = parseComparison(p)
    left = Node(kind: nkBinaryOp, line: opTok.line, col: opTok.col, strVal: opTok.val, left: left, right: right)
  return left

proc parseExpression*(p: var Parser): Node =
  return parseLogical(p)

# Parseo de Bloque de sentencias hasta encontrar 'fin', 'sino', 'caso', 'otro'
proc parseBlock(p: var Parser): Node =
  var stmts: seq[Node] = @[]
  while p.peek().kind != tokEof:
    # Relleno humano antes del cierre: "de fin." cierra igual que "fin.".
    if p.peek().kind == tokKeyword and p.peek().val in ["de", "que", "el", "la", "los", "las", "un", "una", "unos", "unas"] and
       p.peek(1).kind == tokKeyword and p.peek(1).val in ["fin", "sino", "caso", "otro"]:
      discard p.advance()
      continue
    let tok = p.peek()
    if tok.kind == tokKeyword and tok.val in ["fin", "sino", "caso", "otro"]:
      if tok.val == "fin" and p.peek(1).kind in {tokIdent, tokKeyword}:
        discard
      else:
        break
    let stmt = p.parseStatement()
    if stmt != nil:
      stmts.add(stmt)
  return Node(kind: nkBlock, children: stmts)

proc parseTypeWord(p: var Parser): DataTypeKind =
  ## Palabra de tipo tras `como`: entero | decimal | texto | lista (+EN).
  ## `registro` se acepta para dar E202 honesto en sema (aún no cruza).
  ## Sin keywords nuevas.
  let t = p.advance()
  case t.val.toLowerAscii()
  of "entero", "integer", "int": return dtInt
  of "decimal", "float", "double", "flotante": return dtFloat
  of "texto", "string", "cadena", "text": return dtString
  of "lista", "list": return dtList
  of "lista_texto": return dtListStr
  of "lista_listas": return dtListList
  of "registro", "record": return dtRecord
  else:
    p.issues.add(Issue(line: t.line, col: t.col, code: "E001", level: eError,
                       msg: "tipo desconocido: " & t.val, hint: "usa entero, decimal, texto, lista o lista de texto"))
    return dtInt

proc parseStatement*(p: var Parser): Node =
  # Relleno humano al inicio: "de en caso de que...", "la Vida igual...".
  p.skipLeadingFiller()
  let tok = p.peek()

  # 1. mostrar expr1 y expr2.
  if tok.kind == tokKeyword and tok.val == "mostrar":
    discard p.advance()
    var items: seq[Node] = @[]
    items.add(p.parseComparison())
    while p.matchKeyword("y"):
      items.add(p.parseComparison())
    discard p.expectDot()
    return Node(kind: nkMostrar, line: tok.line, col: tok.col, children: items)

  # 2. pedir Variable. ("pedir la Orden." también vale)
  if tok.kind == tokKeyword and tok.val == "pedir":
    discard p.advance()
    p.skipArticlesAfterPrep()
    let varTok = p.advance()
    discard p.expectDot()
    return Node(kind: nkPedir, line: tok.line, col: tok.col, identName: varTok.val)

  # 2b. Ficheros (sesión única): abrir/crear/eliminar "ruta". + cerrar.
  if tok.kind == tokKeyword and tok.val in ["abrir", "crear", "eliminar", "cerrar"]:
    let op = tok.val
    discard p.advance()
    var target: Node = nil
    if op != "cerrar":
      target = p.parsePrimary()
    discard p.expectDot()
    return Node(kind: nkArchivo, line: tok.line, col: tok.col, strVal: op, left: target)

  # 2c. leer Linea. (fichero; tablero es lee X y Y) / escribir X. (una por línea).
  # OJO: peek() es el actual; el siguiente es peek(1).
  if tok.kind == tokKeyword and tok.val == "lee" and p.peek(1).kind == tokIdent and
     p.peek(2).kind != tokKeyword:
    discard p.advance()
    let varTok = p.advance()
    discard p.expectDot()
    return Node(kind: nkLeerLinea, line: tok.line, col: tok.col, identName: varTok.val)
  if tok.kind == tokKeyword and tok.val == "lee" and p.peek(1).kind == tokStr:
    discard p.advance()
    discard p.advance()
    discard p.expectDot()
    p.issues.add(Issue(line: tok.line, col: tok.col, code: "E001", level: eError,
                       msg: "leer quiere variable (abre primero)", hint: "leer Linea."))
    return nil

  if tok.kind == tokKeyword and tok.val == "escribir":
    discard p.advance()
    let valNode = p.parseComparison()
    discard p.expectDot()
    return Node(kind: nkEscribir, line: tok.line, col: tok.col, left: valNode)

  # 2d. Red (sesión única TCP): conectar Host Puerto. / enviar X. / recibir Var. / desconectar.
  if tok.kind == tokKeyword and tok.val == "conectar":
    discard p.advance()
    let hostNode = p.parsePrimary()
    let portNode = p.parsePrimary()
    discard p.expectDot()
    return Node(kind: nkRed, line: tok.line, col: tok.col, strVal: "conectar", left: hostNode, right: portNode)

  if tok.kind == tokKeyword and tok.val == "enviar":
    discard p.advance()
    let valNode = p.parseComparison()
    discard p.expectDot()
    return Node(kind: nkRed, line: tok.line, col: tok.col, strVal: "enviar", left: valNode)

  if tok.kind == tokKeyword and tok.val == "recibir":
    discard p.advance()
    p.skipArticlesAfterPrep()
    let varTok = p.advance()
    discard p.expectDot()
    return Node(kind: nkRed, line: tok.line, col: tok.col, strVal: "recibir", identName: varTok.val)

  if tok.kind == tokKeyword and tok.val == "desconectar":
    discard p.advance()
    discard p.expectDot()
    return Node(kind: nkRed, line: tok.line, col: tok.col, strVal: "desconectar")

  # 3. pisa expr.
  if tok.kind == tokKeyword and tok.val == "pisa":
    discard p.advance()
    let expr = p.parseExpression()
    discard p.expectDot()
    return Node(kind: nkPisa, line: tok.line, col: tok.col, left: expr)

  # 4. en_caso_de_que cond. ... (sino cond. ...)* (sino. ...)? fin.
  if tok.kind == tokKeyword and tok.val == "en_caso_de_que":
    discard p.advance()
    let cond = p.parseExpression()
    var ifLabel = ""
    if p.matchKeyword("como"):
      ifLabel = p.advance().val
    discard p.expectDot()
    let thenBody = p.parseBlock()
    # Cadena de sinos: sino cond (sino_si) repetidos + sino final opcional
    var elseBody: Node = nil
    var elseTail: Node = nil
    proc attachElse(parent: Node, child: Node, root: var Node, tail: var Node) =
      if root == nil:
        root = child
        tail = child
      else:
        tail.elseBlock = child
        tail = child
      discard parent
    while p.matchKeyword("sino"):
      let sinoTok = p.tokens[p.pos - 1]
      if p.peek().kind != tokDot:
        let elseCond = p.parseExpression()
        discard p.expectDot()
        let elseCondBody = p.parseBlock()
        let elseNode = Node(kind: nkIf, line: sinoTok.line, col: sinoTok.col, cond: elseCond, thenBlock: elseCondBody)
        attachElse(nil, elseNode, elseBody, elseTail)
      else:
        discard p.expectDot()
        let finalElse = p.parseBlock()
        if elseTail != nil:
          elseTail.elseBlock = finalElse
        else:
          elseBody = finalElse
        break
    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkIf, line: tok.line, col: tok.col, cond: cond, thenBlock: thenBody, elseBlock: elseBody, label: ifLabel)

  # 5. mientras cond. ... fin.
  if tok.kind == tokKeyword and tok.val == "mientras":
    discard p.advance()
    let cond = p.parseExpression()
    var wLabel = ""
    if p.matchKeyword("como"):
      wLabel = p.advance().val
    discard p.expectDot()
    let body = p.parseBlock()
    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkWhile, line: tok.line, col: tok.col, cond: cond, thenBlock: body, label: wLabel)

  # 6. tick Rate. ... fin.
  if tok.kind == tokKeyword and tok.val == "tick":
    discard p.advance()
    var rate = 0
    if p.peek().kind == tokInt:
      rate = int(p.advance().intVal)
    elif p.matchKeyword("turbo"):
      rate = 0
    var tLabel = ""
    if p.matchKeyword("como"):
      tLabel = p.advance().val
    discard p.expectDot()
    let body = p.parseBlock()
    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkTick, line: tok.line, col: tok.col, intVal: rate, thenBlock: body, label: tLabel)

  # 7. segun expr. caso X. ... otro. ... fin.
  if tok.kind == tokKeyword and tok.val == "segun":
    discard p.advance()
    let matchExpr = p.parseExpression()
    var sLabel = ""
    if p.matchKeyword("como"):
      sLabel = p.advance().val
    discard p.expectDot()
    var branches: seq[Node] = @[]
    var otherBranch: Node = nil

    while p.peek().kind != tokEof and p.peek().val != "fin":
      if p.matchKeyword("caso"):
        var caseValues: seq[Node] = @[]
        caseValues.add(p.parseComparison())
        while p.matchKeyword("y"):
          caseValues.add(p.parseComparison())
        discard p.expectDot()
        let caseStmts = p.parseBlock()
        branches.add(Node(kind: nkCaseBranch, children: caseValues, thenBlock: caseStmts))
      elif p.matchKeyword("otro"):
        discard p.expectDot()
        otherBranch = p.parseBlock()
      else:
        discard p.advance()

    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkMatch, line: tok.line, col: tok.col, cond: matchExpr, children: branches, elseBlock: otherBranch, label: sLabel)

  # 8. por_cada X en Lista (como Etiqueta). ... fin.
  if tok.kind == tokKeyword and tok.val == "por_cada":
    discard p.advance()
    p.skipArticlesAfterPrep()
    let iterVar = p.advance().val
    discard p.matchKeyword("en")
    p.skipArticlesAfterPrep()
    let listNode = p.parsePrimary()
    var loopLabel = ""
    if p.matchKeyword("como"):
      loopLabel = p.advance().val
    discard p.expectDot()
    let body = p.parseBlock()
    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkForEach, line: tok.line, col: tok.col, identName: iterVar, left: listNode, thenBlock: body, label: loopLabel)

  # 9. para (Etiqueta). / sigue (Etiqueta).
  if tok.kind == tokKeyword and tok.val == "para":
    discard p.advance()
    var lbl = ""
    if p.peek().kind in {tokIdent, tokKeyword}:
      lbl = p.advance().val
    discard p.expectDot()
    return Node(kind: nkPara, line: tok.line, col: tok.col, label: lbl)

  if tok.kind == tokKeyword and tok.val == "sigue":
    discard p.advance()
    var lbl2 = ""
    if p.peek().kind in {tokIdent, tokKeyword}:
      lbl2 = p.advance().val
    discard p.expectDot()
    return Node(kind: nkSigue, line: tok.line, col: tok.col, label: lbl2)

  if tok.kind == tokKeyword and tok.val == "fin":
    discard p.advance()
    var lbl3 = ""
    if p.peek().kind in {tokIdent, tokKeyword}:
      lbl3 = p.advance().val
    discard p.expectDot()
    return Node(kind: nkFinLabel, line: tok.line, col: tok.col, label: lbl3)

  # comprobar "Descripcion". ... fin.
  if tok.kind == tokKeyword and tok.val == "comprobar":
    discard p.advance()
    let descNode = p.parsePrimary()
    let desc = if descNode != nil and descNode.kind == nkStr: descNode.strVal else: "prueba"
    discard p.expectDot()
    let body = p.parseBlock()
    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkComprobar, line: tok.line, col: tok.col, strVal: desc, thenBlock: body)

  # 10. devolver X.
  if tok.kind == tokKeyword and tok.val == "devolver":
    discard p.advance()
    let expr = p.parseExpression()
    discard p.expectDot()
    return Node(kind: nkDevolver, line: tok.line, col: tok.col, left: expr)

  # 11. esperar Segs. / limpiar. / lienzo W y H. / tablero ...
  if tok.kind == tokKeyword and tok.val == "esperar":
    discard p.advance()
    let segs = p.parseExpression()
    discard p.expectDot()
    return Node(kind: nkEsperar, line: tok.line, col: tok.col, left: segs)

  if tok.kind == tokKeyword and tok.val == "limpiar":
    discard p.advance()
    discard p.expectDot()
    return Node(kind: nkLimpiar, line: tok.line, col: tok.col)

  if tok.kind == tokKeyword and tok.val == "lienzo":
    discard p.advance()
    let wNode = p.parsePrimary()
    discard p.matchKeyword("y")
    let hNode = p.parsePrimary()
    discard p.expectDot()
    return Node(kind: nkLienzo, line: tok.line, col: tok.col, left: wNode, right: hNode)

  if tok.kind == tokKeyword and tok.val in ["marca", "muro", "moneda", "meta"]:
    let cmd = tok.val
    discard p.advance()
    let xNode = p.parsePrimary()
    discard p.matchKeyword("y")
    let yNode = p.parsePrimary()
    var glyphNode: Node = nil
    if cmd == "marca":
      # `con` es pegamento = `y` tras canonizar; aceptar ambos
      discard (p.matchKeyword("con") or p.matchKeyword("y"))
      glyphNode = p.parsePrimary()
    else:
      let glyph = case cmd
        of "muro": "█"
        of "moneda": "○"
        of "meta": "♦"
        else: " "
      glyphNode = Node(kind: nkStr, line: tok.line, col: tok.col, typ: dtString, strVal: glyph)
    discard p.expectDot()
    return Node(kind: nkMarca, line: tok.line, col: tok.col, left: xNode, right: yNode, target: glyphNode, strVal: cmd)

  if tok.kind == tokKeyword and tok.val == "tablero":
    discard p.advance()
    let xNode = p.parsePrimary()
    discard p.matchKeyword("y")
    let yNode = p.parsePrimary()
    var hasCoinNode: Node = nil
    if p.matchKeyword("y"):
      hasCoinNode = p.parsePrimary()
    discard p.expectDot()
    return Node(kind: nkTablero, line: tok.line, col: tok.col, left: xNode, right: yNode, target: hasCoinNode)

  if tok.kind == tokKeyword and tok.val == "poner":
    discard p.advance()
    let valNode = p.parseExpression()
    discard p.matchKeyword("en")
    p.skipArticlesAfterPrep()
    let fieldName = p.advance().val
    discard p.matchKeyword("de")
    p.skipArticlesAfterPrep()
    let target = p.parsePrimary()
    discard p.expectDot()
    return Node(kind: nkFieldAssign, line: tok.line, col: tok.col, strVal: fieldName, left: target, right: valNode)

  # 12. Listas: Agregar X a L. / Quitar X de L.
  if tok.kind == tokKeyword and tok.val == "agregar":
    discard p.advance()
    let valNode = p.parseExpression()
    discard p.matchKeyword("a")
    p.skipArticlesAfterPrep()
    let targetList = p.parsePrimary()
    discard p.expectDot()
    return Node(kind: nkListAdd, line: tok.line, col: tok.col, left: targetList, right: valNode)

  if tok.kind == tokKeyword and tok.val == "quitar":
    discard p.advance()
    # Forma posicional: Quitar Primero|Ultimo|Elemento N de L. (el acceso ya trae la lista)
    if p.peek().kind == tokKeyword and p.peek().val in ["primero", "ultimo", "elemento"]:
      let operand = p.parsePrimary()
      discard p.expectDot()
      return Node(kind: nkListRemove, line: tok.line, col: tok.col,
                  left: operand.left, right: operand.right, strVal: operand.strVal)
    # Forma por valor: Quitar <primaria> de L. (primaria simple para no comerse el `de`)
    let valNode = p.parsePrimary()
    if p.matchKeyword("de"):
      p.skipArticlesAfterPrep()
      let targetList = p.parsePrimary()
      discard p.expectDot()
      return Node(kind: nkListRemove, line: tok.line, col: tok.col, left: targetList, right: valNode)
    # Sin `de`: eliminar fichero (eliminar/suprimir "ruta".). Solo texto.
    if valNode != nil and (valNode.kind == nkStr or
       (valNode.kind == nkIdent and p.peek().kind == tokDot)):
      discard p.expectDot()
      return Node(kind: nkArchivo, line: tok.line, col: tok.col, strVal: "eliminar", left: valNode)
    p.issues.add(Issue(line: tok.line, col: tok.col, code: "E001", level: eError,
                       msg: "quitar necesita `de Lista` o `\"fichero\"",
                       hint: "Quitar 5 de L. / eliminar \"f.txt\"."))
    discard p.expectDot()
    return nil

  # 13. Declaración de Función: funcion Nombre A y B. ... fin.
  # Params tipados sin keywords nuevas: `funcion F Texto como texto y N.`
  # Retorno opcional: `funcion F A como texto como int.` (ultimo como = retorno)
  if tok.kind == tokKeyword and tok.val == "funcion":
    discard p.advance()
    # `funcion externa F ...` : declaracion FFI (tipo de lista/registro no soportada).
    if p.peek().kind == tokKeyword and p.peek().val == "externa":
      discard p.advance() # consumir 'externa'
      let fnNameTok = p.advance()
      # Saltar la firma hasta el punto (no se implementan externas en v1).
      var sawList = false
      while p.peek().kind != tokDot and p.peek().kind != tokEof:
        let t = p.advance()
        if t.val == "list" or t.val == "lista" or t.val == "registro" or t.val == "record":
          sawList = true
      discard p.expectDot()
      if sawList:
        p.issues.add(Issue(line: tok.line, col: tok.col, code: "E202", level: eError,
                             msg: "funciones externas no admiten listas o registros",
                             hint: "usa enteros, decimales o texto en externas"))
      return nil
    let nameTok = p.peek()
    if nameTok.kind != tokIdent:
      p.issues.add(Issue(line: nameTok.line, col: nameTok.col, code: "E001", level: eError,
                           msg: "el nombre de la funcion debe ir con mayuscula",
                           hint: "usa 'Funcion Sumar X.' no 'funcion sumar X.'"))
      discard p.advance()
      # seguir para no bloquear el parser
    let fnName = p.advance().val
    var params: seq[string] = @[]
    var paramTyps: seq[DataTypeKind] = @[]
    proc takeParam(p: var Parser) =
      params.add(p.advance().val)
      if p.matchKeyword("como"):
        paramTyps.add(p.parseTypeWord())
      else:
        paramTyps.add(dtInt)
    if p.peek().kind == tokIdent:
      p.takeParam()
      while p.matchKeyword("y"):
        # `y B como decimal` o fin de params ante el punto/retorno
        if p.peek().kind == tokIdent:
          p.takeParam()
        else:
          break
    # Tipo de retorno opcional: `como <tipo>` tras los params (antes del punto)
    var retTyp: DataTypeKind = dtInt
    var hasRetTyp = false
    if p.matchKeyword("como"):
      retTyp = p.parseTypeWord()
      hasRetTyp = true
    discard p.expectDot()
    let body = p.parseBlock()
    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkFuncDecl, line: tok.line, col: tok.col, funcName: fnName, params: params, paramTyps: paramTyps, thenBlock: body, typ: retTyp, hasRetTyp: hasRetTyp)

  # 13b. traer Guitarra. (importa coma/lib/guitarra.coma; el driver la resuelve)
  if tok.kind == tokKeyword and tok.val == "traer":
    discard p.advance()
    let modTok = p.advance()
    discard p.expectDot()
    return Node(kind: nkTraer, line: tok.line, col: tok.col, funcName: modTok.val)

  # 14. Declaración de Registro en bloque: registro Nombre: ... fin.
  if tok.kind == tokKeyword and tok.val == "registro" and p.peek(1).kind == tokIdent and p.peek(2).kind == tokColon:
    discard p.advance() # consumir 'registro'
    let regName = p.advance().val
    discard p.advance() # consumir ':'
    var fields: seq[tuple[name: string, val: Node]] = @[]
    while p.peek().kind != tokEof and p.peek().val != "fin":
      let fTok = p.advance()
      let fVal = p.parsePrimary()
      discard p.expectDot()
      fields.add((capitalizeAscii(fTok.val), fVal))
    discard p.matchKeyword("fin")
    discard p.expectDot()
    return Node(kind: nkRecordBlock, line: tok.line, col: tok.col, recordName: regName, fields: fields)

  # 15. Punteros: puntero Alias a Original.
  if tok.kind == tokKeyword and tok.val == "puntero":
    discard p.advance()
    let aliasTok = p.advance().val
    discard p.matchKeyword("a")
    let origTok = p.advance().val
    discard p.expectDot()
    return Node(kind: nkPointerDecl, line: tok.line, col: tok.col, identName: aliasTok, strVal: origTok)

  # direccion de X: direccion/asador de una variable (FFI, sin implementar plenamente).
  if tok.kind == tokKeyword and tok.val == "direccion":
    discard p.advance()
    discard p.matchKeyword("de")
    let targetTok = p.advance()
    discard p.expectDot()
    return Node(kind: nkDireccion, line: tok.line, col: tok.col, identName: targetTok.val, strVal: targetTok.val)

  # gpu iniciar. / gpu ejecutar D a V. (GPU no implementada en v1).
  if tok.kind == tokKeyword and tok.val == "gpu":
    discard p.advance()
    if p.matchKeyword("iniciar"):
      discard p.expectDot()
      return nil
    elif p.matchKeyword("ejecutar"):
      let dest = p.parsePrimary()
      discard p.matchKeyword("a")
      let val = p.parsePrimary()
      discard p.expectDot()
      p.issues.add(Issue(line: tok.line, col: tok.col, code: "E202", level: eError,
                         msg: "gpu ejecutar no soporta este tipo de destino",
                         hint: "usa un destino de GPU valido"))
      return nil
    discard p.expectDot()
    return nil

  # 16. Asignaciones (sondeo con rebobinado: si no hay `igual` no se
  # consumió nada y cae al fallback de expresión suelta).
  # Elemento 2 de L igual 99.
  if tok.kind == tokKeyword and tok.val in ["elemento", "primero", "ultimo"]:
    let savePos = p.pos
    let saveIss = p.issues.len
    let op = tok.val
    discard p.advance()
    var idxNode: Node = nil
    if op == "elemento":
      idxNode = p.parsePrimary()
    discard p.matchKeyword("de")
    p.skipArticlesAfterPrep()
    let listNode = p.parsePrimary()
    if p.matchKeyword("igual"):
      let valNode = p.parseExpression()
      discard p.expectDot()
      return Node(kind: nkListAssign, line: tok.line, col: tok.col, strVal: op, left: listNode, right: idxNode, target: valNode)
    p.pos = savePos
    p.issues.setLen(saveIss)

  # Vida de E igual X. ("Vida de el Heroe" también vale)
  if tok.kind == tokIdent and p.peek(1).kind == tokKeyword and p.peek(1).val == "de":
    let savePos = p.pos
    let saveIss = p.issues.len
    let fieldName = p.advance().val
    discard p.advance() # consumir 'de'
    p.skipArticlesAfterPrep()
    let target = p.parsePrimary()
    if p.matchKeyword("igual"):
      let valNode = p.parseExpression()
      discard p.expectDot()
      return Node(kind: nkFieldAssign, line: tok.line, col: tok.col, strVal: fieldName, left: target, right: valNode)
    p.pos = savePos
    p.issues.setLen(saveIss)

  # Variable igual expr. O Variable mas/menos/por/entre expr.
  if tok.kind == tokIdent:
    let savePos = p.pos
    let saveIss = p.issues.len
    let varTok = p.advance()
    if p.matchKeyword("igual"):
      # Bloque `G igual lista de registros:` + renglones + `fin.` (o abre con `.`).
      if p.peek().kind == tokKeyword and p.peek().val == "lista_de_registros" and
         (p.peek(1).kind == tokDot or p.peek(1).kind == tokColon):
        let hdr = p.advance()
        discard p.advance() # '.' o ':'
        var rows: seq[Node] = @[]
        while p.peek().kind != tokEof and
              not (p.peek().kind == tokKeyword and p.peek().val == "fin"):
          if p.peek().kind == tokKeyword and p.peek().val == "registro":
            let row = p.parsePrimary()
            discard p.expectDot()
            if row != nil: rows.add(row)
          else:
            let bad = p.advance()
            p.issues.add(Issue(line: bad.line, col: bad.col, code: "E001", level: eError,
                               msg: "en lista de registros se esperaba registro ... o fin",
                               hint: "renglon como: registro Vida 30 y Ataque 5."))
        discard p.matchKeyword("fin")
        discard p.expectDot()
        return Node(kind: nkAssign, line: varTok.line, col: varTok.col, identName: varTok.val,
                    left: Node(kind: nkListRecordLit, line: hdr.line, col: hdr.col, children: rows))
      let expr = p.parseExpression()
      discard p.expectDot()
      return Node(kind: nkAssign, line: varTok.line, col: varTok.col, identName: varTok.val, left: expr)
    elif p.peek().kind == tokKeyword and p.peek().val in ["mas", "menos", "por", "entre"]:
      let op = p.advance().val
      let right = p.parseExpression()
      discard p.expectDot()
      # Azúcar: X mas 1. -> X = X + 1
      let selfNode = Node(kind: nkIdent, line: varTok.line, col: varTok.col, identName: varTok.val)
      let binOp = Node(kind: nkBinaryOp, line: varTok.line, col: varTok.col, strVal: op, left: selfNode, right: right)
      return Node(kind: nkAssign, line: varTok.line, col: varTok.col, identName: varTok.val, left: binOp)
    elif p.peek().kind in {tokInt, tokFloat, tokStr, tokIdent}:
      # Llamada a función suelta (se descarta retorno): Sumar 3 y 5.
      # parseComparison como en el resto de llamadas (el `y` separa
      # argumentos, no es AND: eso vive un nivel más arriba).
      # Solo vale si termina en punto; si sigue comparación
      # (Golpe 2 y 3 es_igual_a 5.) se rebobina al fallback de abajo.
      var args: seq[Node] = @[]
      args.add(p.parseComparison())
      while p.matchKeyword("y"):
        args.add(p.parseComparison())
      if p.peek().kind == tokDot:
        discard p.expectDot()
        return Node(kind: nkCall, line: varTok.line, col: varTok.col, funcName: varTok.val, args: args)
      p.pos = savePos
      p.issues.setLen(saveIss)
    elif p.peek().kind == tokDot and varTok.val in p.funcNames:
      # Llamada sin argumentos (firma conocida): Verde.
      discard p.expectDot()
      return Node(kind: nkCall, line: varTok.line, col: varTok.col, funcName: varTok.val, args: @[])
    p.pos = savePos
    p.issues.setLen(saveIss)

  # Asignación con nombre minúscula (no reservada): `contador igual 5.`
  if tok.kind == tokKeyword and not esIniciadorDeSentencia(tok.val) and
     p.peek(1).kind == tokKeyword and p.peek(1).val == "igual":
    let varName = tok.val
    discard p.advance()  # nombre
    discard p.advance()  # 'igual'
    let expr = p.parseExpression()
    discard p.expectDot()
    return Node(kind: nkAssign, line: tok.line, col: tok.col, identName: varName, left: expr)

  # Expresión suelta como sentencia
  let expr = p.parseExpression()
  if expr != nil:
    discard p.expectDot()
    return Node(kind: nkExprStmt, line: tok.line, col: tok.col, left: expr)

  # Si no hace match con ninguna sentencia conocida, avanzar y registrar issue
  let bad = p.advance()
  p.issues.add(Issue(line: bad.line, col: bad.col, code: "E001", level: eError,
                     msg: "sentencia no reconocida: " & bad.val, hint: "revisa la sintaxis del lenguaje"))
  return nil

proc parseProgram*(tokens: seq[Token], issues: var seq[Issue],
                   extraFuncs: seq[string] = @[]): Node =
  var p = newParser(tokens, extraFuncs)
  var stmts: seq[Node] = @[]

  while p.peek().kind != tokEof:
    let stmt = p.parseStatement()
    if stmt != nil:
      stmts.add(stmt)

  issues.add(p.issues)
  return Node(kind: nkProgram, children: stmts)
