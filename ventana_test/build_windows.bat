@echo off
setlocal
set COMA_COMPILER=D:\AgmineEngine\coma\nim\coma.exe
set SRC=D:\AgmineEngine\coma\ventana_test\corazon_math.coma
echo Compilando para Windows (x86_64-windows-gnu)...
%COMA_COMPILER% "%SRC%" --target:x86_64-windows-gnu --salida:D:\AgmineEngine\coma\ventana_test\corazon_math_win.exe 
if errorlevel 1 goto :error
echo Listo: D:\AgmineEngine\coma\ventana_test\corazon_math_win.exe
echo Ejecutando...
"D:\AgmineEngine\coma\ventana_test\corazon_math_win.exe"
goto :end
:error
echo ERROR: compilacion fallida
:end
