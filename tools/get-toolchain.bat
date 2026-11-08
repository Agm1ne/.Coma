@echo off
rem ============================================================================
rem  get-toolchain.bat — el usuario NO tiene que instalar nada.
rem
rem  Descarga el toolchain portable de LLVM (zig), verifica su SHA256 y lo
rem  deja en tools\toolchain\zig\ . El compilador lo encuentra solo: no hay
rem  que tocar el PATH ni instalar nada en el sistema.
rem
rem  Es idempotente: si ya esta, no hace nada.
rem
rem  Uso: doble clic, o
rem      tools\get-toolchain.bat
rem ============================================================================
setlocal
cd /d "%~dp0.."

set "TOOLCHAIN=%CD%\tools\toolchain"
set "ZIGVER=0.17.0"
set "COMA_ZIG_URL=https://ziglang.org/download/%ZIGVER%/zig-x86_64-windows-%ZIGVER%.zip"
set "COMA_ZIG_SHA=b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428"
set "COMA_TOOLCHAIN=%TOOLCHAIN%"
set "COMA_ZIG_ZIP=%TOOLCHAIN%\zig-%ZIGVER%.zip"

if exist "%TOOLCHAIN%\zig\zig.exe" goto :listo

if not exist "%TOOLCHAIN%" mkdir "%TOOLCHAIN%"

echo.
echo [1/4] Descargando zig %ZIGVER% (95 MB)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri $env:COMA_ZIG_URL -OutFile $env:COMA_ZIG_ZIP"
if errorlevel 1 (
  echo [MAL] la descarga fallo. Revisa la conexion y vuelve a intentarlo.
  exit /b 1
)

echo [2/4] Verificando SHA256...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$h=(Get-FileHash -Algorithm SHA256 -LiteralPath $env:COMA_ZIG_ZIP).Hash.ToLower(); if ($h -eq $env:COMA_ZIG_SHA) { Write-Host '       SHA256 ok.' } else { Write-Host ('       MAL: ' + $h); exit 1 }"
if errorlevel 1 (
  echo [MAL] SHA256 distinto al esperado: el archivo no es el esperado.
  del /q "%COMA_ZIG_ZIP%" 2>nul
  exit /b 1
)

echo [3/4] Extrayendo en tools\toolchain\ ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $t=$env:COMA_TOOLCHAIN; if (Test-Path (Join-Path $t 'zig')) { Remove-Item (Join-Path $t 'zig') -Recurse -Force }; Expand-Archive -LiteralPath $env:COMA_ZIG_ZIP -DestinationPath $t -Force; Get-ChildItem -Directory $t | Where-Object { $_.Name -like 'zig-*' } | ForEach-Object { Move-Item $_.FullName (Join-Path $t 'zig') -Force }; Remove-Item $env:COMA_ZIG_ZIP -Force"
if errorlevel 1 (
  echo [MAL] fallo la extraccion.
  exit /b 1
)

if not exist "%TOOLCHAIN%\zig\zig.exe" (
  echo [MAL] no se encontro zig.exe tras extraer.
  exit /b 1
)

:listo
echo [4/4] Listo.
echo.
"%TOOLCHAIN%\zig\zig.exe" version
echo.
echo Ya puedes compilar .coma sin haber instalado nada:
echo     nim\coma.exe juego\cripta.coma
echo.
exit /b 0
