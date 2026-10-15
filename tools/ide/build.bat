@echo off
setlocal
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo [ERROR] No se encuentra csc.exe en %CSC%.
  exit /b 1
)
cd /d "%~dp0"
echo [INFO] Compilando coma-ide.exe...
"%CSC%" /nologo /target:winexe /out:coma-ide.exe ide.cs /reference:System.Windows.Forms.dll,System.Drawing.dll
if errorlevel 1 (
  echo [ERROR] Fallo al compilar coma-ide.exe.
  exit /b 1
)
echo [INFO] coma-ide.exe listo. Doble clic para abrir.
echo [INFO] Autoprueba: coma-ide.exe --selftest
"%~dp0coma-ide.exe" --selftest
if errorlevel 1 exit /b 1
echo [INFO] Prueba del popup: coma-ide.exe --uitest
"%~dp0coma-ide.exe" --uitest
if errorlevel 1 exit /b 1
echo [INFO] Todo OK. Cierra cualquier ventana vieja del IDE y abre esta.
