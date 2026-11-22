# Builds real Geometry 8 tasks (Atanasyan 7-9, 2023-2026 edition) and
# validates the catalog. ASCII only: Windows PowerShell 5.1 reads BOM-less
# UTF-8 as ANSI, so Cyrillic messages would turn into garbage.
$ErrorActionPreference = 'Continue'

$env:Path = 'C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;' + $env:Path
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_CACHE = 'C:\dev\pub-cache'

Set-Location 'C:\dev\gdz_app'

Write-Host '============================================================'
Write-Host '  Geometry 8 (Atanasyan 2023-2026): building real tasks'
Write-Host '  Sources: budu5.com, gdz.ru, reshak.ru'
Write-Host '  Takes 10-20 minutes. Do NOT close this window.'
Write-Host '============================================================'
Write-Host ''

if (-not (Test-Path 'assets\data\catalog.json')) {
  Write-Host 'ERROR: assets\data\catalog.json not found.'
  Read-Host 'Press Enter to close'
  exit 1
}

Copy-Item 'assets\data\catalog.json' 'tool\catalog_before_geo.json' -Force

& 'C:\dev\flutter\bin\dart.bat' 'tool\rebuild_geometry8.dart' 2>&1 |
  Tee-Object -FilePath 'tool\geo_build.log'
$buildExit = $LASTEXITCODE

Write-Host ''
Write-Host '--- catalog validation ---'
& 'C:\dev\flutter\bin\dart.bat' 'tool\validate_catalog.dart' 2>&1 |
  Tee-Object -FilePath 'tool\geo_build.log' -Append
$validateExit = $LASTEXITCODE

Write-Host ''
Write-Host '============================================================'
Write-Host ("  Done. build exit = {0}, validation exit = {1}" -f $buildExit, $validateExit)
Write-Host '  Report: C:\dev\gdz_app\tool\geometry8_report.txt'
Write-Host '============================================================'
Read-Host 'Press Enter to close this window'
