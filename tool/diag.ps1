Get-CimInstance Win32_Process -Filter "Name='dart.exe' OR Name='flutter.exe' OR Name='java.exe' OR Name='cloudflared.exe' OR Name='powershell.exe' OR Name='cmd.exe'" |
  Select-Object ProcessId, Name, @{n='Started';e={$_.CreationDate}}, @{n='Cmd';e={$_.CommandLine.Substring(0, [Math]::Min(160, $_.CommandLine.Length))}} |
  Sort-Object Started |
  Format-Table -AutoSize |
  Out-String -Width 300 |
  Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot "diag.txt")
