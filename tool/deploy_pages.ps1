param(
  [Parameter(Mandatory = $true)][string]$Owner,
  [string]$Repo = "gdz-app",
  [string]$ApkUrl = ""
)

# Собирает веб-версию с правильным base-href и публикует её в ветку gh-pages.
# Пример:
#   powershell -File tool\deploy_pages.ps1 -Owner mylogin `
#     -ApkUrl https://github.com/mylogin/gdz-app/releases/download/v1.0.0/gdz-app.apk

$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "C:\dev\jdk17"
$env:ANDROID_HOME = "C:\dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_CACHE = "C:\dev\pub-cache"
$env:Path = "C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $root
try {
  $arguments = @("build", "web", "--release", "--no-pub", "--base-href", "/$Repo/")
  if ($ApkUrl) { $arguments += "--dart-define=APK_URL=$ApkUrl" }

  Write-Host "=== flutter build web ($($arguments -join ' ')) ==="
  & flutter @arguments
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $pages = Join-Path (Split-Path $root -Parent) "gdz_app_pages"
  if (Test-Path $pages) { Remove-Item -Recurse -Force $pages }
  New-Item -ItemType Directory $pages | Out-Null
  Copy-Item "build\web\*" $pages -Recurse -Force
  New-Item -ItemType File (Join-Path $pages ".nojekyll") | Out-Null

  Push-Location $pages
  try {
    git init -b gh-pages | Out-Null
    git add -A
    git commit -m "Deploy web build" | Out-Null
    git remote add origin "https://github.com/$Owner/$Repo.git"
    Write-Host "=== git push gh-pages ==="
    git push -f origin gh-pages
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }

  Write-Host ""
  Write-Host "Готово: https://$Owner.github.io/$Repo/"
} finally {
  Pop-Location
}
