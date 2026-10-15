# ESTACION CENTRAL â€” mini-aventura de consola en espanol.
# Homenaje a .Coma: comandos en minusculas, errores humanos con sugerencia.
# Compilar: nim c -d:release aventura.nim
# Jugar: aventura.exe (escribe comandos como: mirar, ir norte, coger billete)

import std/[strutils, tables]

when defined(windows):
  proc SetConsoleOutputCP(cp: uint32): cint {.stdcall, dynlib: "kernel32", importc.}
  discard SetConsoleOutputCP(65001)  # UTF-8 en consola: tildes y eñes bien

type
  Room = object
    name, desc: string
    exits: Table[string, string] # direccion -> sala
    items: seq[string]

const
  Verbos = ["mirar", "ir", "coger", "tomar", "inventario", "usar", "ayuda", "salir"]
  Dirs = ["norte", "sur", "este", "oeste"]

proc canonDir(s: string): string =
  ## Acepta n/s/e/o y nombres completos.
  case s
  of "n", "norte": "norte"
  of "s", "sur": "sur"
  of "e", "este": "este"
  of "o", "oeste": "oeste"
  else: ""

proc lev(a, b: string): int =
  ## Distancia de edicion (sugerencias estilo E003 de .Coma).
  var d = newSeq[int]((a.len + 1) * (b.len + 1))
  template at(x, y: int): int = y * (a.len + 1) + x
  for x in 0 .. a.len: d[at(x, 0)] = x
  for y in 0 .. b.len: d[at(0, y)] = y
  for y in 1 .. b.len:
    for x in 1 .. a.len:
      let cost = if a[x - 1] == b[y - 1]: 0 else: 1
      d[at(x, y)] = min(min(d[at(x - 1, y)] + 1, d[at(x, y - 1)] + 1),
                        d[at(x - 1, y - 1)] + cost)
  d[at(a.len, b.len)]

proc sugiere(word: string, cands: openArray[string]): string =
  var best = ""
  var bestD = 3
  for c in cands:
    let dd = lev(word, c)
    if dd < bestD: (bestD, best) = (dd, c)
  best

proc ex(pairs: varargs[(string, string)]): Table[string, string] =
  toTable(pairs)

var salas = initTable[string, Room]()
salas["anden"] = Room(name: "Anden", desc: "El anden huele a lluvia. Un reloj marca las 9 en punto. Al este se ve el vestibulo.",
  exits: ex(("este", "vestibulo")), items: @[])
salas["vestibulo"] = Room(name: "Vestibulo", desc: "El vestibulo hierve de viajeros. Taquilla al norte, anden al oeste y la puerta de la Via 9 al este, con revisor.",
  exits: ex(("norte", "taquilla"), ("oeste", "anden"), ("este", "via9")), items: @[])
salas["taquilla"] = Room(name: "Taquilla", desc: "Ventanilla de laton. Sobre el mostrador brilla un billete olvidado. La salida esta al sur.",
  exits: ex(("sur", "vestibulo")), items: @["billete"])
salas["via9"] = Room(name: "Via 9", desc: "La via secreta. El tren espera con la puerta abierta y humo dulce.",
  exits: ex(), items: @[])

let ItemDesc = ex(("billete", "un billete a la Via 9, aun caliente"))

var
  sala = "anden"
  mochila: seq[string] = @[]
  puerta = false
  turnos = 0
  jugando = true

proc mirar() =
  let r = salas[sala]
  echo "\n== " & r.name & " =="
  echo r.desc
  if r.exits.len > 0:
    var salidas: seq[string] = @[]
    for d in r.exits.keys: salidas.add(d)
    echo "Salidas: " & salidas.join(" y ") & "."
  else:
    echo "No hay salidas visibles."
  if r.items.len > 0:
    echo "Ves: " & r.items.join(" y ") & "."

proc ir(arg: string) =
  let d = canonDir(arg)
  if d == "":
    let s = sugiere(arg, Dirs)
    echo "No se a donde es eso." & (if s != "": " Quisiste decir Â«" & s & "?" else: "")
    return
  if d notin salas[sala].exits:
    echo "Por ahi no se puede ir."
    return
  if sala == "vestibulo" and d == "este" and not puerta:
    echo "El revisor te frena: sin billete no hay Via 9. Prueba con Â«usar billeteÂ»."
    return
  sala = salas[sala].exits[d]
  inc turnos
  mirar()
  if sala == "via9":
    echo "\nSubes al tren. La maquina resopla y la estacion queda atras."
    echo "VICTORIA en " & $turnos & " turnos. Gracias por jugar."
    jugando = false

proc coger(arg: string) =
  if arg == "":
    echo "Coger que? Di Â«coger billeteÂ»."
    return
  let idx = salas[sala].items.find(arg)
  if idx < 0:
    let pool = salas[sala].items & mochila
    let s = sugiere(arg, pool)
    echo "Aqui no hay eso." & (if s != "": " Quisiste decir Â«" & s & "?" else: "")
    return
  mochila.add(arg)
  salas[sala].items.del(idx)
  echo "Guardas " & ItemDesc.getOrDefault(arg, arg) & "."

proc usar(arg: string) =
  if arg == "":
    echo "Usar que?"
    return
  if arg notin mochila:
    echo "No tienes eso en la mochila."
    return
  if arg == "billete" and sala == "vestibulo" and not puerta:
    puerta = true
    echo "El revisor pica tu billete. La puerta de la Via 9 queda abierta."
  elif arg == "billete":
    echo "Ya no hace falta: la puerta esta abierta."
  else:
    echo "Nada interesante pasa."

proc ayuda() =
  echo "Comandos: mirar | ir <norte/sur/este/oeste> | coger <cosa> | inventario | usar <cosa> | ayuda | salir."

echo "ESTACION CENTRAL â€” escribe Â«ayudaÂ» si te pierdes."
mirar()
while jugando:
  stdout.write("\n> ")
  var linea: string
  try: linea = stdin.readLine()
  except EOFError: break
  let partes = linea.strip().toLowerAscii().splitWhitespace()
  if partes.len == 0: continue
  let verbo = partes[0]
  let arg = if partes.len > 1: partes[1 .. ^1].join(" ") else: ""
  case verbo
  of "mirar", "m": mirar()
  of "ir": ir(arg)
  of "coger", "tomar": coger(arg)
  of "inventario", "i":
    echo if mochila.len == 0: "Mochila vacia." else: "Llevas: " & mochila.join(" y ") & "."
  of "usar": usar(arg)
  of "ayuda": ayuda()
  of "salir": echo "Hasta la proxima."; jugando = false
  else:
    let s = sugiere(verbo, Verbos)
    echo "No entiendo eso." & (if s != "": " Quisiste decir Â«" & s & "?" else: "")
