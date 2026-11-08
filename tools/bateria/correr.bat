@echo off
setlocal enabledelayedexpansion

set "DIR=%~dp0casos\"
set "COMA=D:\AgmineEngine\coma\nim\coma.exe"
set "OK=0"
set "FAIL=0"

echo [INFO] motor.dll de prueba...

REM Limpiar artefactos
del /f /q "%DIR%*.exe" "%DIR%*.ll" "%DIR%*.tmp" "%DIR%*.pdb" "%DIR%*.obj" 2>nul

REM Iterar sobre casos .coma
for %%F in ("%DIR%*.coma") do call :run_test "%%F"

REM Limpiar artefactos al final
del /f /q "%DIR%*.exe" "%DIR%*.ll" "%DIR%*.tmp" "%DIR%*.pdb" "%DIR%*.obj" 2>nul
del /f /q "%DIR%*.sal" 2>nul

echo.
echo BATERIA: !OK! bien, !FAIL! mal.
exit /b 0

:run_test
set "BASENAME=%~n1"
set "FILENAME=%~nx1"

REM Saltar helper, tests de ventana OpenGL y tests min
if /i "%FILENAME%"=="falsa.coma" exit /b 0
if /i "%FILENAME%"=="ok_ventana_abrir_cerrar.coma" exit /b 0
if /i "%FILENAME%"=="ok_ventana_dibujar.coma" exit /b 0
if /i "%FILENAME%"=="run_ventana_sprite_E105.coma" exit /b 0
if /i "%FILENAME%"=="mal_ventana_color_falta_E001.coma" exit /b 0
if /i "%FILENAME%"=="test_min.coma" exit /b 0

set "IS_MAL=0"
set "EXPECTED_ERR="

REM Detectar mal_*_E### y extraer codigo de error
echo %FILENAME% | findstr /r /b "mal_" >nul
if not errorlevel 1 (
    set "IS_MAL=1"
    set "TEMP=%~n1"
    set "TEMP=!TEMP:_= !"
    for %%T in (!TEMP!) do set "LASTTOK=%%T"
    set "EXPECTED_ERR=!LASTTOK!"
)

REM Detectar run_
echo %FILENAME% | findstr /r /b "run_" >nul
set "IS_RUN=!errorlevel!"

if "%IS_MAL%"=="1" (
    set "SALFILE=%DIR%%BASENAME%.sal"
    "%COMA%" "%DIR%%FILENAME%" > "!SALFILE!" 2>&1
    if not errorlevel 1 (
        echo [MAL] %BASENAME%: compilo debiendo fallar
        set /a FAIL+=1
        exit /b 0
    )
    findstr /i "!EXPECTED_ERR!" "!SALFILE!" >nul 2>nul
    if errorlevel 1 (
        echo [MAL] %BASENAME%: fallo con error distinto a !EXPECTED_ERR!
        set /a FAIL+=1
        exit /b 0
    )
    echo [OK] %BASENAME% (falla con !EXPECTED_ERR!)
    set /a OK+=1
    exit /b 0
)

if "!IS_RUN!"=="1" (
    "%COMA%" "%DIR%%FILENAME%" >nul 2>&1
    if errorlevel 1 (
        echo [MAL] %BASENAME%: no compilo
        set /a FAIL+=1
        exit /b 0
    )
    "%DIR%%BASENAME%.exe" > "%DIR%%BASENAME%.tmp" 2>&1
    if not errorlevel 1 (
        echo [MAL] %BASENAME%: runtime no fallo
        set /a FAIL+=1
        exit /b 0
    )
    fc /w "%DIR%%BASENAME%.tmp" "%DIR%%BASENAME%.txt" >nul 2>nul
    if errorlevel 1 (
        echo [MAL] %BASENAME!: salida no coincide
        set /a FAIL+=1
        exit /b 0
    )
    echo [OK] %BASENAME% (falla en vivo)
    set /a OK+=1
    exit /b 0
)

REM Test ok_
"%COMA%" "%DIR%%FILENAME%" >nul 2>&1
if errorlevel 1 (
    echo [MAL] %BASENAME%: no compilo
    set /a FAIL+=1
    exit /b 0
)
"%DIR%%BASENAME%.exe" > "%DIR%%BASENAME%.tmp" 2>&1
fc /w "%DIR%%BASENAME%.tmp" "%DIR%%BASENAME%.txt" >nul 2>nul
if errorlevel 1 (
    echo [MAL] %BASENAME!: salida no coincide
    set /a FAIL+=1
    exit /b 0
)
echo [OK] %BASENAME%
set /a OK+=1
exit /b 0
