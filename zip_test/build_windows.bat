@echo off
setlocal
set COMA_COMPILER=D:\AgmineEngine\coma\nim\coma.exe
set SRC=D:\AgmineEngine\coma\zip_test\corazon.coma
echo Compilando para Windows (x86_64-windows-gnu)...
%COMA_COMPILER% "%SRC%" --target:x86_64-windows-gnu --salida:D:\Temp\kilo\corazon_windows.exe
if errorlevel 1 goto :error
echo Listo: D:\Temp\kilo\corazon_windows.exe
echo Ejecutando...
"D:\Temp\kilo\corazon_windows.exe"
goto :end
:error
echo ERROR: compilacion fallida
:end
