@echo off
setlocal enabledelayedexpansion

set COMA=..\nim\coma.exe
set DUELO=..\duelo
set RESULT=result.txt

echo ============================================ > %RESULT%
echo   DUELO: .Coma vs C Benchmarks >> %RESULT%
echo ============================================ >> %RESULT%
echo. >> %RESULT%

echo [1/3] Suma 1..5 (Computo puro)
echo --- Coma ---
%COMA% "%DUELO%\suma_coma.coma"
echo --- C ---
gcc -O2 -o "%DUELO%\benchmark_suma.exe" "%DUELO%\benchmark_suma.c"
"%DUELO%\benchmark_suma.exe"
echo.

echo [2/3] Busqueda lineal en lista
echo --- Coma ---
%COMA% "%DUELO%\buscar_coma.coma"
echo --- C ---
gcc -O2 -o "%DUELO%\benchmark_buscar.exe" "%DUELO%\benchmark_buscar.c"
"%DUELO%\benchmark_buscar.exe"
echo.

echo [3/3] Tablero de consola (Render optimizado)
echo --- Coma ---
%COMA% "%DUELO%\tablero_coma.coma"
echo.
echo ============================================
echo   DUELO completo. Revisa result.txt para el resumen.
echo ============================================
