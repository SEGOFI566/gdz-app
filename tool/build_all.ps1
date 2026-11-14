# Полная пересборка: веб-версия + APK.
# Запуск: powershell -ExecutionPolicy Bypass -File tool\build_all.ps1
$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "C:\dev\jdk17"
$env:ANDROID_HOME = "C:\dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_CACHE = "C:\dev\pub-cache"
$env:Path = "C:\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"

Push-Location (Join-Path $PSScriptRoot "..")
try {
  Write-Host "=== pub get ==="
  flutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "=== build web ==="
  flutter build web --release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "=== build apk ==="
  & (Join-Path $PSScriptRoot "build_apk.ps1")
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "=== result ==="
  Get-Item "build\download\gdz-app.apk" |
    ForEach-Object { "APK: {0} MB, {1}" -f [math]::Round($_.Length / 1MB, 1), $_.LastWriteTime }
  Get-Item "build\web\main.dart.js" |
    ForEach-Object { "WEB: {0} KB, {1}" -f [math]::Round($_.Length / 1KB, 0), $_.LastWriteTime }
} finally {
  Pop-Location
}
