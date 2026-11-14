param(
  [Parameter(Mandatory = $true)][string]$Owner,
  [string]$Repo = "gdz-app"
)
$ErrorActionPreference = "Continue"
$env:Path = "C:\dev\git\cmd;C:\dev\gh\bin;$env:Path"

Write-Host "=== POST pages ==="
gh api --method POST "repos/$Owner/$Repo/pages" -f "source[branch]=gh-pages" -f "source[path]=/" 2>&1

Write-Host "=== GET pages ==="
gh api "repos/$Owner/$Repo/pages" 2>&1

Write-Host "=== latest build ==="
gh api "repos/$Owner/$Repo/pages/builds/latest" 2>&1
