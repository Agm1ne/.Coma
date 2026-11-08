# ============================================
# COMA REPL - Read-Eval-Print Loop
# Cada linea se compila y ejecuta individualmente
# Comandos: :ayuda :ver :limpiar :salir
# ============================================

$buffer = @()
$comaExe = "$PSScriptRoot\..\..\nim\coma.exe"
$tempFile = "$env:TEMP\comarepl.coma"

Write-Host "=== COMA REPL ==="
Write-Host "Escribe codigo COMA y presiona Enter para ejecutar"
Write-Host "Comandos: :ayuda :ver :limpiar :salir"
Write-Host ""

while ($true) {
    Write-Host "coma> " -NoNewline
    $line = Read-Host
    
    if ($line -eq ":salir") {
        break
    }
    if ($line -eq ":ayuda") {
        Write-Host "Comandos disponibles:"
        Write-Host "  :ayuda  - Mostrar esta ayuda"
        Write-Host "  :ver    - Mostrar buffer actual"
        Write-Host "  :limpiar - Limpiar buffer"
        Write-Host "  :salir  - Salir del REPL"
        Write-Host ""
        continue
    }
    if ($line -eq ":ver") {
        Write-Host "Buffer actual:"
        $buffer | ForEach-Object { Write-Host "  $_" }
        continue
    }
    if ($line -eq ":limpiar") {
        $buffer = @()
        Write-Host "Buffer limpiado."
        continue
    }
    
    # Agregar linea al buffer
    $buffer += $line
    
    # Escribir buffer a archivo temporal
    $buffer | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Compilar y ejecutar
    $output = & $comaExe $tempFile 2>&1
    if ($output -match "OK: LLVM IR") {
        # Compilacion exitosa, ejecutar
        $exeFile = $tempFile -replace "\.coma$", ".exe"
        $runOutput = & $exeFile 2>&1
        Write-Host $runOutput
    } else {
        Write-Host $output
    }
    Write-Host ""
}

Write-Host "Adios!"
