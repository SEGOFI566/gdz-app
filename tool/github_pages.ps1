param(
  [Parameter(Mandatory = $true)][string]$Owner,
  [string]$Repo = "gdz-app",
  [string]$Tag = "v1.0.0"
)

# 1) Uploads the APK to GitHub Releases (if the release does not exist yet).
# 2) Builds the web version with the GitHub Pages base path and pushes gh-pages.
# 3) Enables GitHub Pages.
$ErrorActionPreference = "Stop"
$env:Path = "C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;$env:Path"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$apk = Join-Path $root "build\download\gdz-app.apk"
if (-not (Test-Path $apk)) { throw "APK not found: $apk" }

$apkUrl = "https://github.com/$Owner/$Repo/releases/download/$Tag/gdz-app.apk"

$ErrorActionPreference = "Continue"
gh release view $Tag --repo "$Owner/$Repo" > $null 2>&1
$hasRelease = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if (-not $hasRelease) {
  Write-Host "=== create release $Tag ==="
  gh release create $Tag $apk --repo "$Owner/$Repo" --title "GDZ 1.0.0" --notes "Android APK."
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
  Write-Host "=== refresh APK in release $Tag ==="
  gh release upload $Tag $apk --repo "$Owner/$Repo" --clobber
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "=== update release notes ==="
$ErrorActionPreference = "Continue"
$catalog = Get-Content -Raw -Encoding UTF8 (Join-Path $root "assets\data\catalog.json") | ConvertFrom-Json
$taskCount = $catalog.tasks.Count
$bookCount = $catalog.textbooks.Count
gh release edit $Tag --repo "$Owner/$Repo" --notes "Android APK. Catalog: $bookCount textbooks, $taskCount tasks with solutions."
$ErrorActionPreference = "Stop"

Write-Host "=== deploy web ==="
& (Join-Path $PSScriptRoot "deploy_pages.ps1") -Owner $Owner -Repo $Repo -ApkUrl $apkUrl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== enable pages ==="
$ErrorActionPreference = "Continue"
gh api --method POST "repos/$Owner/$Repo/pages" -f "source[branch]=gh-pages" -f "source[path]=/" > $null 2>&1
gh api --method PUT "repos/$Owner/$Repo/pages" -f "source[branch]=gh-pages" -f "source[path]=/" > $null 2>&1
$ErrorActionPreference = "Stop"

gh api "repos/$Owner/$Repo/pages" --jq '"pages: \(.html_url) status=\(.status)"'
Write-Host "APK: $apkUrl"
Write-Host "Site: https://$Owner.github.io/$Repo/"
