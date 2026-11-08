@echo off
REM Iniciar servidor Agmine Coin (100% Coma)
cd /d "%~dp0"
echo Compilando servidor.coma...
..\nim\coma.exe servidor.coma
if %ERRORLEVEL% NEQ 0 (
    echo Error de compilacion.
    pause
    exit /b 1
)
echo Compilacion exitosa. Iniciando servidor en puerto 8080...
echo Abre http://localhost:8080 en tu navegador.
servidor.exe
pause