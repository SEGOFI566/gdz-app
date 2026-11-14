# Verify APK contents: the catalog inside must match assets/data/catalog.json.
# ASCII only: Windows PowerShell 5.1 reads BOM-less UTF-8 as ANSI.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$apk = Join-Path $PSScriptRoot "..\build\download\gdz-app.apk"
$apk = (Resolve-Path $apk).Path
$zip = [System.IO.Compression.ZipFile]::OpenRead($apk)
try {
  $entry = $zip.Entries | Where-Object { $_.FullName -like "*assets/data/catalog.json" } | Select-Object -First 1
  if (-not $entry) { throw "catalog.json not found in APK" }
  $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
  try { $json = $reader.ReadToEnd() } finally { $reader.Dispose() }
} finally {
  $zip.Dispose()
}

$catalog = $json | ConvertFrom-Json
$bark = $catalog.textbooks | Where-Object { $_.id -eq "russian-8-barkhudarov" }
$barkTasks = @($catalog.tasks | Where-Object { $_.textbookId -eq "russian-8-barkhudarov" })
$pages = $barkTasks | ForEach-Object { $_.page }

"APK:        $apk"
"Size:       {0} MB" -f [math]::Round((Get-Item $apk).Length / 1MB, 1)
"Textbooks:  $($catalog.textbooks.Count)"
"Tasks:      $($catalog.tasks.Count)"
"Barkhudarov tasks: $($barkTasks.Count)"
"Barkhudarov pages: $(($pages | Measure-Object -Minimum).Minimum) - $(($pages | Measure-Object -Maximum).Maximum)"
"ISBN:       $($bark.isbn)"
"Book pages: $($bark.pages)"
