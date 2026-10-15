# Spike 2 (.Coma en Nim): validacion gramatical con npeg.
# Clasifica cada linea de un .coma y reporta E001/E006.
# Uso: parse.exe ejemplos\oleada.coma
import npeg, os, strutils

proc maskStrings(line: string): string =
  result = newString(line.len)
  var i = 0
  var inStr = false
  while i < line.len:
    if not inStr:
      if line[i] == '"': inStr = true
      result[i] = if inStr: ' ' else: line[i]
      inc i
    else:
      if line[i] == '"':
        if i + 1 < line.len and line[i + 1] == '"':
          result[i] = ' '; result[i + 1] = ' '; i += 2
        else: inStr = false; result[i] = ' '; inc i
      else: result[i] = ' '; inc i

# El codigo llega sin textos (enmascarados) y sin comentarios (quitados).
# Gramatica npeg real: * = secuencia, - = diferencia, prefijos ?+*!&.
let gramatica = peg "todo":
  todo   <- codigo * '.' * (*' ')
  codigo <- +nodo
  nodo   <- {'\x00'..'\xff'} - '.'

proc main(path: string): int =
  var sentencias, vacias, e001, e006 = 0
  var num = 0
  for raw in lines(path):
    inc num
    let masked = maskStrings(raw)
    var pipes = 0
    for c in masked:
      if c == '|': inc pipes
    var code = masked
    let pos = masked.find('|')
    if pos >= 0:
      # quita |...| por parejas y cola abierta
      var res = masked
      var idx: seq[int] = @[]
      for i, c in masked:
        if c == '|': idx.add(i)
      var k = 0
      while k + 1 < idx.len:
        for j in idx[k] .. idx[k + 1]: res[j] = ' '
        k += 2
      if idx.len mod 2 == 1:
        for j in idx[^1] ..< res.len: res[j] = ' '
        inc e006
        echo "linea " & $num & " [E006 aviso]: barra | sin cerrar"
      code = res
    if code.strip() == "":
      inc vacias
      continue
    let m = match(gramatica, code)
    if m.ok and m.matchLen == code.len:
      inc sentencias
      let primero = code.strip().splitWhitespace()[0]
      if num <= 3: echo "linea " & $num & " OK (" & primero & ")"
    else:
      inc e001
      echo "linea " & $num & " [E001 error]: falta el punto final :: " & raw.strip()
  echo "---"
  echo "sentencias=" & $sentencias & " vacias=" & $vacias &
    " E001=" & $e001 & " E006=" & $e006
  if e001 > 0: 1 else: 0

quit(main(paramStr(1)))
