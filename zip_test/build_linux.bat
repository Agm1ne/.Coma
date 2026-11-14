@echo off
setlocal
set COMA_COMPILER=D:\AgmineEngine\coma\nim\coma.exe
set SRC=D:\AgmineEngine\coma\zip_test\corazon.coma
echo Compilando para Linux (x86_64-linux, cruzado desde Windows)...
%COMA_COMPILER% "%SRC%" --target:x86_64-linux --salida:D:\Temp\kilo\corazon_linux
if errorlevel 1 goto :error
echo Listo: D:\Temp\kilo\corazon_linux (ELF x86-64)
echo Para ejecutar en WSL2:
echo   wsl.exe -d Ubuntu -e chmod +x "/mnt/d/Temp/kilo/corazon_linux"
echo   wsl.exe -d Ubuntu -e "/mnt/d/Temp/kilo/corazon_linux"
goto :end
:error
echo ERROR: compilacion fallida
:end
