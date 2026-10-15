# Spike 1 (.Coma en Nim): emision de LLVM IR en texto.
# Toma `devolver 40 mas 2.` ya plegado (40+2=42) y escupe el modulo .ll.
# El .ll resultante se ensambla con llc cuando haya toolchain LLVM.
# Uso: emitir.exe > suma.ll
import strutils

const Núcleo = 40 + 2  # plegado constante: lo que hara la inferencia de .Coma

proc emiteIR(valor: int): string =
  result = "; Modulo generado por .Coma v0.1 (spike)\n"
  result &= "target triple = \"x86_64-pc-windows-msvc\"\n\n"
  result &= "define i32 @main() {\n"
  result &= "entry:\n"
  result &= "  ret i32 " & $valor & "\n"
  result &= "}\n"

echo emiteIR(Núcleo)
