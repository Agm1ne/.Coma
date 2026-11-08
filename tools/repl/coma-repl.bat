@echo off
:: COMA REPL - Read-Eval-Print Loop
:: Cada linea se compila y ejecuta individualmente

setlocal enabledelayedexpansion

set "COMA_EXE=%~dp0..\..\nim\coma.exe"
set "TEMP_FILE=%TEMP%\comarepl.coma"

echo ============================================
echo   COMA REPL - Read-Eval-Print Loop
echo ============================================
echo Escribe codigo COMA y presiona Enter para ejecutar
echo Comandos: :ayuda :ver :limpiar :salir
echo.

set BUFFER=

:loop
set /p "line=coma> "

if "%line%"==":salir" goto end
if "%line%"==":ayuda" goto ayuda
if "%line%"==":ver" goto ver
if "%line%"==":limpiar" goto limpiar

:: Agregar linea al buffer
if defined BUFFER (
    set "BUFFER=!BUFFER!^
%line%"
) else (
    set "BUFFER=%line%"
)

:: Escribir buffer a archivo temporal
echo !BUFFER! > "%TEMP_FILE%"

:: Compilar
"%COMA_EXE%" "%TEMP_FILE%" 2>&1
if %ERRORLEVEL% neq 0 goto next

:: Ejecutar
set "EXE_FILE=%TEMP_FILE:.coma=.exe%"
"%EXE_FILE%" 2>&1

:next
echo.
goto loop

:ayuda
echo.
write Comando disponibles:
echo   :ayuda  - Mostrar esta ayuda
echo   :ver    - Mostrar buffer actual
echo   :limpiar - Limpiar buffer
echo   :salir  - Salir del REPL
echo.
goto loop

:ver
echo.
echo Buffer actual:
echo !BUFFER!
echo.
goto loop

:limpiar
set BUFFER=
echo Buffer limpiado.
goto loop

:end
echo Adios!
