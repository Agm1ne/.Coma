[Console]::OutputEncoding = [Text.Encoding]::UTF8
$con = Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern System.IntPtr GetStdHandle(int n); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(System.IntPtr h, ref int m); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(System.IntPtr h, int m);' -Name "ConsolaJuego" -Namespace "Mazmorra" -PassThru
$h = $con::GetStdHandle(-11)
$md = 0
if ($con::GetConsoleMode($h, [ref]$md)) { $con::SetConsoleMode($h, ($md -bor 4)) | Out-Null }
$f = 'D:\AgmineEngine\coma\juego\sesion-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log'
$m2 = 0
[void]$con::GetConsoleMode($h, [ref]$m2)
Add-Content $f ('VT:' + $m2)
& 'D:\AgmineEngine\coma\juego\mazmorra.exe' 2>&1 | Tee-Object -FilePath $f
Add-Content $f ('EXITCODE:' + $LASTEXITCODE)
