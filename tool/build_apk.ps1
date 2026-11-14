param(
  [string]$Mode = "release"
)

# Сборка APK. Требует JDK 17 и Android SDK (ставятся в C:\dev\jdk17 и C:\dev\android-sdk).
$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "C:\dev\jdk17"
$env:ANDROID_HOME = "C:\dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
# Кэш пакетов обязан лежать в ASCII-пути: пакет jni собирается через
# CMake/ninja, а они не умеют работать с кириллицей в пути.
$env:PUB_CACHE = "C:\dev\pub-cache"
$env:Path = "C:\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"

Push-Location (Join-Path $PSScriptRoot "..")
try {
  flutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter build apk --$Mode
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $apk = "build\app\outputs\flutter-apk\app-$Mode.apk"
  if (-not (Test-Path $apk)) {
    Write-Host "APK не найден: $apk" -ForegroundColor Red
    exit 1
  }

  $outDir = "build\download"
  New-Item -ItemType Directory -Force $outDir | Out-Null
  Copy-Item $apk (Join-Path $outDir "gdz-app.apk") -Force

  $size = [math]::Round((Get-Item (Join-Path $outDir "gdz-app.apk")).Length / 1MB, 1)
  Write-Host ""
  Write-Host "APK готов: build\download\gdz-app.apk ($size MB)" -ForegroundColor Green
  Write-Host "Скачать: http://localhost:8080/download/gdz-app.apk"
} finally {
  Pop-Location
}
