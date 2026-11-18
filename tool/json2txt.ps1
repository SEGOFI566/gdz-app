$ErrorActionPreference = "Stop"
$src = "C:\dev\gdz_app\tool\ocr_pg10.json"
$dst = "C:\dev\gdz_app\tool\ocr_pg10.txt"
$j = Get-Content -Raw -Encoding UTF8 $src | ConvertFrom-Json
[System.IO.File]::WriteAllText($dst, $j.ParsedResults[0].ParsedText, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("chars: " + $j.ParsedResults[0].ParsedText.Length)
