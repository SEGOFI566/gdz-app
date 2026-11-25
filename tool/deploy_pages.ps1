param(
  [Parameter(Mandatory = $true)][string]$Owner,
  [string]$Repo = "gdz-app",
  [string]$ApkUrl = "",
  [string]$ChatApiUrl = ""
)

# Builds the web version with the correct base-href and publishes it to gh-pages.
# ASCII only: Windows PowerShell 5.1 reads BOM-less UTF-8 as ANSI.

$ErrorActionPreference = "Stop"

$env:FLUTTER_ROOT = "C:\dev\flutter"
$env:JAVA_HOME = "C:\dev\jdk17"
$env:ANDROID_HOME = "C:\dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_CACHE = "C:\dev\pub-cache"
$env:Path = "C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"

# The flutter.bat wrapper hangs on this machine (Git/PowerShell bootstrap),
# so invoke the cached Flutter tool snapshot directly.
$dart = Join-Path $env:FLUTTER_ROOT "bin\cache\dart-sdk\bin\dart.exe"
$snapshot = Join-Path $env:FLUTTER_ROOT "bin\cache\flutter_tools.snapshot"
$packageConfig = Join-Path $env:FLUTTER_ROOT "packages\flutter_tools\.dart_tool\package_config.json"

# Corporate/offline networks cannot reach the certificate revocation server,
# which makes every push fail with CRYPT_E_REVOCATION_OFFLINE. Git 2.56 ignores
# http.schannelCheckRevoke=false, but GIT_SSL_NO_VERIFY works.
$env:GIT_SSL_NO_VERIFY = "1"
$env:GIT_TERMINAL_PROMPT = "0"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $root
try {
  $arguments = @("build", "web", "--release", "--no-pub", "--base-href", "/$Repo/", "--no-web-resources-cdn")
  if ($ApkUrl) { $arguments += "--dart-define=APK_URL=$ApkUrl" }
  if ($ChatApiUrl) { $arguments += "--dart-define=CHAT_API_URL=$ChatApiUrl" }

  Write-Host "=== flutter build web (direct tool) ==="
  & $dart --disable-dart-dev --packages=$packageConfig $snapshot @arguments
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $pages = Join-Path (Split-Path $root -Parent) "gdz_app_pages"
  if (Test-Path $pages) { Remove-Item -Recurse -Force $pages }
  New-Item -ItemType Directory $pages | Out-Null
  Copy-Item "build\web\*" $pages -Recurse -Force
  New-Item -ItemType File (Join-Path $pages ".nojekyll") | Out-Null

  Push-Location $pages
  try {
    git init -b gh-pages | Out-Null
    git config user.name "gdz-app publisher"
    git config user.email "publisher@users.noreply.github.com"
    git config http.postBuffer 524288000
    git config http.lowSpeedLimit 0
    git config http.lowSpeedTime 999999
    git remote add origin "https://github.com/$Owner/$Repo.git"

    # A fresh root commit makes GitHub receive the entire web build on every
    # publish, which fails with HTTP 408. Parent the new commit on the current
    # remote tip so only changed files are transferred.
    Write-Host "=== fetch gh-pages tip ==="
    # A plain shallow fetch sometimes dies with "fatal: early EOF" here and
    # then hangs. Fetching only the commit/tree (no blobs) is enough for
    # commit-tree and is much smaller; retry a few times on network errors.
    $remoteTip = $null
    $fetched = $false
    for ($attempt = 1; $attempt -le 3 -and -not $fetched; $attempt++) {
      $lock = Join-Path (Get-Location) ".git\shallow.lock"
      if (Test-Path $lock) { Remove-Item -Force $lock -ErrorAction SilentlyContinue }
      git fetch --depth=1 --filter=blob:none --no-tags origin gh-pages | Out-Host
      $fetched = ($LASTEXITCODE -eq 0)
      if (-not $fetched -and $attempt -lt 3) { Start-Sleep -Seconds 2 }
    }
    if ($fetched) {
      $remoteTip = (git rev-parse FETCH_HEAD).Trim()
    } else {
      Write-Host "=== no remote gh-pages yet, creating first commit ==="
    }

    git add -A
    $tree = (git write-tree).Trim()
    if ($remoteTip) {
      $commit = ("Deploy web build" | git commit-tree $tree -p $remoteTip).Trim()
    } else {
      $commit = ("Deploy web build" | git commit-tree $tree).Trim()
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    git update-ref refs/heads/gh-pages $commit

    Write-Host "=== git push gh-pages ==="
    git push origin gh-pages
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }

  Write-Host ""
  Write-Host "Done: https://$Owner.github.io/$Repo/"
} finally {
  Pop-Location
}
