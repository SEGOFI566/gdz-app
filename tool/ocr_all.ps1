param(
  [string]$ImageDir = "C:\dev\gdz_app\tool\img2022",
  [string]$OutDir = "C:\dev\gdz_app\tool\ocr_pages",
  [string]$Tesseract = "C:\dev\tesseract\tesseract.exe",
  [double]$Scale = 2.5
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory $OutDir | Out-Null }
if (-not (Test-Path $Tesseract)) { throw "tesseract not found: $Tesseract" }

$files = Get-ChildItem $ImageDir -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png)$' } | Sort-Object Name
Write-Host ("images: " + $files.Count)

$tmp = Join-Path $env:TEMP "ocr_scaled.png"
$i = 0
foreach ($f in $files) {
  $i++
  $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $outBase = Join-Path $OutDir $base
  $outTxt = "$outBase.txt"
  if (Test-Path $outTxt) { continue }

  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $w = [int]($img.Width * $Scale)
  $h = [int]($img.Height * $Scale)
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, 0, 0, $w, $h)
  $g.Dispose()
  $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $img.Dispose()

  & $Tesseract $tmp $outBase -l rus --psm 6 -c preserve_interword_spaces=1 2>$null | Out-Null
  if ($i % 10 -eq 0) { Write-Host ("done $i / " + $files.Count) }
}
Write-Host "finished"
