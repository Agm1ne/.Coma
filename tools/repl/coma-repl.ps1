# coma-repl.ps1 - REPL simple de .Coma (un solo archivo temporal, sin guardar ni cargar).
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File coma-repl.ps1
# Comandos (empiezan por `:`): :ayuda :salir :limpiar :ver :log :en :es
param([string]$ComaExe = "")

$ErrorActionPreference = "Stop"
$replDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsDir = Split-Path -Parent $replDir
$rootDir = Split-Path -Parent $toolsDir
if ($ComaExe -eq "") { $ComaExe = Join-Path $rootDir "nim\coma.exe" }
$sesion = Join-Path ([System.IO.Path]::GetTempPath()) "coma_repl.coma"
$lineas = New-Object System.Collections.Generic.List[string]
$logOn = $false
$logLineas = New-Object System.Collections.Generic.List[string]
$idioma = "es"

function horaAhora { return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }

function mostrarAyuda {
  Write-Host ".Coma REPL - escribe sentencias terminadas en punto (.)." -ForegroundColor Yellow
  Write-Host "  Cada linea se suma a la sesion y se ejecuta todo junto." -ForegroundColor Gray
  Write-Host "  :ayuda   esta ayuda" -ForegroundColor Gray
  Write-Host "  :ver     muestra la sesion actual" -ForegroundColor Gray
  Write-Host "  :limpiar vacia la sesion y empieza de cero" -ForegroundColor Gray
  Write-Host "  :log     activa/apaga guardar el diario en sesion-*.log" -ForegroundColor Gray
  Write-Host "  :es/:en  idioma del diario (palabras en espanol o ingles)" -ForegroundColor Gray
  Write-Host "  :salir   termina (guarda el diario si esta activado)" -ForegroundColor Gray
}

function apendLog([string]$t) {
  if ($logOn) { $logLineas.Add("[" + (horaAhora) + "] " + $t) | Out-Null }
}

function ejecutarSesion {
  $codigo = ($lineas -join "`r`n") + "`r`n"
  [System.IO.File]::WriteAllText($sesion, $codigo, [System.Text.Encoding]::UTF8)
  $exe = [System.IO.Path]::ChangeExtension($sesion, ".exe")
  & $ComaExe "$sesion" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    $quitada = $lineas[$lineas.Count - 1]
    $lineas.RemoveAt($lineas.Count - 1)
    apendLog ("!! linea revertida (rompia la sesion): " + $quitada)
    Write-Host "(esa linea rompia la sesion: se quito sola, lo demas sigue intacto)" -ForegroundColor Red
    return
  }
  if (Test-Path $exe) {
    Write-Host "--- salida ---" -ForegroundColor DarkGray
    & $exe
    Write-Host "--------------" -ForegroundColor DarkGray
  }
}

mostrarAyuda
apendLog "== sesion REPL .Coma iniciada"
while ($true) {
  $n = $lineas.Count + 1
  Write-Host -NoNewline ("coma({0})> " -f $n) -ForegroundColor Cyan
  $ent = Read-Host
  if ($null -eq $ent) { break }
  $ent = $ent.Trim()
  if ($ent -eq "") { continue }
  if ($ent.StartsWith(":")) {
    $cmd = $ent.ToLower()
    if ($cmd -eq ":salir" -or $cmd -eq ":quit" -or $cmd -eq ":q") {
      if ($logOn -and $logLineas.Count -gt 0) {
        $f = Join-Path (Get-Location) ("sesion-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + ".log")
        [System.IO.File]::WriteAllLines($f, $logLineas, [System.Text.Encoding]::UTF8)
        $msg = "Diario guardado en " + $f + " (" + $logLineas.Count + " lineas). Para el resto de tu vida."
        Write-Host $msg -ForegroundColor Green
      }
      apendLog "== sesion terminada =="
      return
    }
    elseif ($cmd -eq ":limpiar" -or $cmd -eq ":clear") {
      $lineas.Clear()
      apendLog "-- sesion limpiada, se empieza de cero --"
      Write-Host "Sesion vacia. De cero." -ForegroundColor Yellow
      continue
    }
    elseif ($cmd -eq ":ver" -or $cmd -eq ":show") {
      if ($lineas.Count -eq 0) { Write-Host "(sesion vacia)" -ForegroundColor Gray }
      else { for ($i = 0; $i -lt $lineas.Count; $i++) { Write-Host ("{0,3}: {1}" -f ($i + 1), $lineas[$i]) -ForegroundColor Gray } }
      continue
    }
    elseif ($cmd -eq ":log") {
      $logOn = -not $logOn
      if ($logOn) { $estado = "ACTIVADO (se guarda al salir)" } else { $estado = "apagado" }
      apendLog "-- diario cambiado a: $estado --"
      Write-Host ("Diario: " + $estado) -ForegroundColor Yellow
      continue
    }
    elseif ($cmd -eq ":en") { $idioma = "en"; apendLog "-- idioma del diario: ingles --"; Write-Host "Idioma: ingles (palabras en ingles)." -ForegroundColor Yellow; continue }
    elseif ($cmd -eq ":es") { $idioma = "es"; apendLog "-- idioma del diario: espanol --"; Write-Host "Idioma: espanol (palabras en espanol)." -ForegroundColor Yellow; continue }
    elseif ($cmd -eq ":ayuda" -or $cmd -eq ":help" -or $cmd -eq ":h") { mostrarAyuda; continue }
    else { Write-Host "Comando desconocido. Prueba :ayuda." -ForegroundColor Red; continue }
  }
  $lineas.Add($ent)
  apendLog ("> " + $ent)
  ejecutarSesion
}
