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
git -c core.quotepath=false commit -m "GDZ app: catalog, solutions, web and Android builds" | Out-Null

$existing = & gh repo view "$owner/gdz-app" --json name 2>$null
if ($LASTEXITCODE -ne 0) {
  gh repo create "$owner/gdz-app" --public --source=. --remote=origin --push --description "GDZ app for grades 5-11: Flutter catalog of textbooks, tasks and solutions"
} else {
  if (-not (& git remote)) { git remote add origin "https://github.com/$owner/gdz-app.git" }
  git push -u origin main
}

Write-Host "=== repo ==="
gh repo view "$owner/gdz-app" --json url,visibility,defaultBranchRef --jq '"url=\(.url) visibility=\(.visibility) branch=\(.defaultBranchRef.name)"'
