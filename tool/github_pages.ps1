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
  gh release create $Tag $apk --repo "$Owner/$Repo" --title "GDZ 1.0.0" --notes "Android APK. Catalog: 23 textbooks, 456 tasks with solutions."
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
  Write-Host "Release $Tag already exists."
}

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
