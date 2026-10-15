# opt.nim — Optimizaciones propias de .Coma (las que C no puede hacer por ti).
# 1) Plegado de constantes con semántica Coma (entre siempre decimal,
#    división por cero NO se pliega: la caza E102 en runtime).
# 2) Propagación conservadora: una sola asignación literal, mismo ámbito,
#    uso posterior a la definición (las funciones empiezan con env vacío:
#    el orden de llamada no se conoce).
import ast, strutils

proc foldNode(n: Node): Node =
  if n == nil: return nil
  case n.kind
  of nkBinaryOp:
    n.left = foldNode(n.left)
    n.right = foldNode(n.right)
    let L = n.left
    let R = n.right
    if L == nil or R == nil: return n
    if L.kind == nkInt and R.kind == nkInt:
      case n.strVal
      of "mas": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal + R.intVal)
      of "menos": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal - R.intVal)
      of "por": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal * R.intVal)
      of "y_bit": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal and R.intVal)
      of "o_bit": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal or R.intVal)
      of "xor": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal xor R.intVal)
      of "desplaza_izquierda": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal shl R.intVal)
      of "desplaza_derecha": return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: L.intVal shr R.intVal)
      of "entre":
        if R.intVal == 0: return n # E102 en runtime, no aquí
        return Node(kind: nkFloat, line: n.line, col: n.col, typ: dtFloat,
                    floatVal: float(L.intVal) / float(R.intVal))
      of "es_igual_a", "igual":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal == R.intVal: 1 else: 0))
      of "es_equivalente_a":
        if L.kind == nkStr and R.kind == nkStr:
          return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                      intVal: (if L.strVal.toLowerAscii() == R.strVal.toLowerAscii(): 1 else: 0))
        if L.kind == nkInt and R.kind == nkInt:
          return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                      intVal: (if L.intVal == R.intVal: 1 else: 0))
      of "es_mayor_que":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal > R.intVal: 1 else: 0))
      of "es_menor_que":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal < R.intVal: 1 else: 0))
      of "es_distinto_de":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal != R.intVal: 1 else: 0))
      of "es_mayor_o_igual":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal >= R.intVal: 1 else: 0))
      of "es_menor_o_igual":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal <= R.intVal: 1 else: 0))
      else: return n
    if (L.kind == nkFloat or L.kind == nkInt) and
       (R.kind == nkFloat or R.kind == nkInt):
      let lf = if L.kind == nkFloat: L.floatVal else: float(L.intVal)
      let rf = if R.kind == nkFloat: R.floatVal else: float(R.intVal)
      case n.strVal
      of "mas": return Node(kind: nkFloat, line: n.line, col: n.col, typ: dtFloat, floatVal: lf + rf)
      of "menos": return Node(kind: nkFloat, line: n.line, col: n.col, typ: dtFloat, floatVal: lf - rf)
      of "por": return Node(kind: nkFloat, line: n.line, col: n.col, typ: dtFloat, floatVal: lf * rf)
      of "entre":
        if rf == 0.0: return n
        return Node(kind: nkFloat, line: n.line, col: n.col, typ: dtFloat, floatVal: lf / rf)
      of "es_igual_a", "igual":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if lf == rf: 1 else: 0))
      of "es_mayor_que":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if lf > rf: 1 else: 0))
      of "es_menor_que":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if lf < rf: 1 else: 0))
      of "es_distinto_de":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if lf != rf: 1 else: 0))
      else: return n
    if L.kind == nkStr and R.kind == nkStr and
       n.strVal in ["es_igual_a", "igual", "es_distinto_de"]:
      let eq = L.strVal == R.strVal
      let v = if n.strVal == "es_distinto_de": not eq else: eq
      return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                  intVal: (if v: 1 else: 0))
    if L.kind == nkBool and R.kind == nkBool:
      case n.strVal
      of "y":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal != 0 and R.intVal != 0: 1 else: 0))
      of "o":
        return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                    intVal: (if L.intVal != 0 or R.intVal != 0: 1 else: 0))
      else: return n
    return n
  of nkUnaryOp:
    n.left = foldNode(n.left)
    if n.left != nil and n.left.kind == nkInt and n.strVal == "menos":
      return Node(kind: nkInt, line: n.line, col: n.col, typ: dtInt, intVal: -n.left.intVal)
    if n.left != nil and n.left.kind == nkFloat and n.strVal == "menos":
      return Node(kind: nkFloat, line: n.line, col: n.col, typ: dtFloat, floatVal: -n.left.floatVal)
    if n.left != nil and n.left.kind == nkBool and n.strVal == "no":
      return Node(kind: nkBool, line: n.line, col: n.col, typ: dtBool,
                  intVal: (if n.left.intVal == 0: 1 else: 0))
    return n
  else:
    # Recursión genérica: expresiones hijas primero.
    if n.left != nil: n.left = foldNode(n.left)
    if n.right != nil: n.right = foldNode(n.right)
    if n.target != nil: n.target = foldNode(n.target)
    if n.cond != nil: n.cond = foldNode(n.cond)
    for i in 0 ..< n.args.len: n.args[i] = foldNode(n.args[i])
    for i in 0 ..< n.children.len: n.children[i] = foldNode(n.children[i])
    for i in 0 ..< n.fields.len:
      n.fields[i] = (n.fields[i].name, foldNode(n.fields[i].val))
    if n.thenBlock != nil: n.thenBlock = foldNode(n.thenBlock)
    if n.elseBlock != nil: n.elseBlock = foldNode(n.elseBlock)
    return n

proc isConstLit(n: Node): bool =
  n != nil and n.kind in {nkInt, nkFloat, nkStr, nkBool}

proc substIds(n: Node, env: seq[tuple[name: string, val: Node]]) =
  ## Sustituye idents por su literal (mismo ámbito, ya validado).
  if n == nil: return
  case n.kind
  of nkIdent:
    for e in env:
      if e.name == n.identName:
        n.kind = e.val.kind
        n.intVal = e.val.intVal
        n.floatVal = e.val.floatVal
        n.strVal = e.val.strVal
        n.typ = e.val.typ
        return
  of nkFuncDecl:
    return # otro ámbito: ni mirar
  else: discard
  if n.left != nil: substIds(n.left, env)
  if n.right != nil: substIds(n.right, env)
  if n.target != nil: substIds(n.target, env)
  if n.cond != nil: substIds(n.cond, env)
  for a in n.args: substIds(a, env)
  for c in n.children: substIds(c, env)
  for f in n.fields: substIds(f.val, env)
  if n.thenBlock != nil: substIds(n.thenBlock, env)
  if n.elseBlock != nil: substIds(n.elseBlock, env)

proc killName(env: var seq[tuple[name: string, val: Node]], name: string) =
  var i = 0
  while i < env.len:
    if env[i].name == name: env.del(i)
    else: inc i

proc scanWrites(x: Node, touched: var seq[string]) =
  ## Nombres asignados bajo x (sin entrar en funciones: otro ámbito).
  if x == nil: return
  if x.kind == nkAssign: touched.add(x.identName)
  elif x.kind == nkPedir: touched.add(x.identName)
  elif x.kind == nkLeerLinea: touched.add(x.identName)
  elif x.kind == nkRed and x.strVal == "recibir": touched.add(x.identName)
  elif x.kind == nkForEach: touched.add(x.identName)
  elif x.kind == nkFuncDecl: return
  if x.left != nil: scanWrites(x.left, touched)
  if x.right != nil: scanWrites(x.right, touched)
  if x.target != nil: scanWrites(x.target, touched)
  if x.cond != nil: scanWrites(x.cond, touched)
  for a in x.args: scanWrites(a, touched)
  for c in x.children: scanWrites(c, touched)
  for f in x.fields: scanWrites(f.val, touched)
  if x.thenBlock != nil: scanWrites(x.thenBlock, touched)
  if x.elseBlock != nil: scanWrites(x.elseBlock, touched)

proc propBlock(stmts: var seq[Node], outer: seq[tuple[name: string, val: Node]]) =
  ## Una pasada en orden: registra (nombre=único literal), sustituye usos
  ## posteriores, invalida al segundo asignar. Los bucles/ifs primero
  ## invalidan lo que escriben y luego sustituyen (si no, mentiría).
  var env = outer
  for s in stmts:
    if s == nil: continue
    case s.kind
    of nkAssign:
      substIds(s.left, env) # con el valor VIEJO si se reasigna a sí misma
      killName(env, s.identName)
      if isConstLit(s.left):
        env.add((s.identName, s.left))
    of nkPedir:
      killName(env, s.identName)
    of nkLeerLinea:
      killName(env, s.identName)
    of nkRed:
      if s.strVal == "recibir":
        killName(env, s.identName)
    of nkForEach:
      killName(env, s.identName)
      var touched: seq[string] = @[]
      if s.thenBlock != nil: scanWrites(s.thenBlock, touched)
      for t in touched: killName(env, t)
      substIds(s, env)
    of nkFuncDecl:
      discard # su ámbito es suyo; ni registra ni invalida el de fuera
    else:
      var touched: seq[string] = @[]
      scanWrites(s, touched)
      for t in touched: killName(env, t)
      substIds(s, env)

proc propagateProgram(root: Node) =
  if root == nil or root.kind != nkProgram: return
  propBlock(root.children, @[])
  for s in root.children:
    if s != nil and s.kind == nkFuncDecl and s.thenBlock != nil and
       s.thenBlock.kind == nkBlock:
      propBlock(s.thenBlock.children, @[])

proc optimizeProgram*(root: Node) =
  ## Plegado (fondo) + propagación (forma). Idempotente y seguro.
  if root == nil: return
  discard foldNode(root)
  propagateProgram(root)
  discard foldNode(root)
