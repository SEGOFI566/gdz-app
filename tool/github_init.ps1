# Create the GitHub repo, make the first commit and push the source code.
$ErrorActionPreference = "Stop"
$env:Path = "C:\dev\git\cmd;C:\dev\gh\bin;$env:Path"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root

$owner = (& gh api user --jq .login).Trim()
$id = (& gh api user --jq .id).Trim()
Write-Host "Owner: $owner (id $id)"

gh auth setup-git
git config --global user.name $owner
git config --global user.email "$id+$owner@users.noreply.github.com"
git config --global init.defaultBranch main

if (-not (Test-Path (Join-Path $root ".git"))) {
  git init -b main | Out-Null
}

git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  git commit -m "GDZ app: catalog, solutions, web and Android builds" | Out-Null
}

$ErrorActionPreference = "Continue"
gh repo view "$owner/gdz-app" --json name > $null 2>&1
$exists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if (-not $exists) {
  Write-Host "Creating repository..."
  gh repo create "$owner/gdz-app" --public --source=. --remote=origin --push --description "GDZ app for grades 5-11: Flutter catalog of textbooks, tasks and solutions"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
  Write-Host "Repository exists, pushing..."
  if (-not (git remote 2>$null)) { git remote add origin "https://github.com/$owner/gdz-app.git" }
  git push -u origin main
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "=== repo ==="
gh repo view "$owner/gdz-app" --json url,visibility,defaultBranchRef --jq '"url=\(.url) visibility=\(.visibility) branch=\(.defaultBranchRef.name)"'
