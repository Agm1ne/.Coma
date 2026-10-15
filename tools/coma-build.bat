@echo off
setlocal
rem coma-build.bat — compila cualquier .coma en un comando.
rem Uso: coma-build.bat programa.coma [--opt:0] [--ir]
rem El .exe sale junto al .coma. Requiere zig en PATH.

set "TOOLS=%~dp0"
set "TOOLS=%TOOLS:~0,-1%"
set "ROOT=%TOOLS%\.."
set "COMA=%ROOT%\nim\coma.exe"

if "%~1"=="" (
  echo Uso: coma-build.bat programa.coma [--opt:0] [--ir]
  exit /b 1
)
if not exist "%COMA%" (
  echo [ERROR] No se encuentra %COMA%.
  exit /b 1
)
"%COMA%" %*
