$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# OCR the two textbook photos via OCR.space (free test key).
# ASCII-only script: paths are built from $env:USERPROFILE.

$files = @(
  (Join-Path $env:USERPROFILE "Downloads\12ee08f8-ade0-4fa2-bd70-5acc7c080c08.jpg"),
  (Join-Path $env:USERPROFILE "Downloads\51a14238-274f-4803-bfaf-078fe8294086.jpg")
)

$i = 0
foreach ($f in $files) {
  $i++
  if (-not (Test-Path $f)) { Write-Host "missing: $f"; continue }

  $img = [System.Drawing.Image]::FromFile($f)
  $maxW = 1800
  $scale = [Math]::Min(1.0, $maxW / $img.Width)
  $w = [int]($img.Width * $scale)
  $h = [int]($img.Height * $scale)
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, 0, 0, $w, $h)
  $g.Dispose()

  $ms = New-Object System.IO.MemoryStream
  $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ps = New-Object System.Drawing.Imaging.EncoderParameters 1
  $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]85)
  $bmp.Save($ms, $enc, $ps)
  $bmp.Dispose()
  $img.Dispose()

  $bytes = $ms.ToArray()
  Write-Host ("file {0}: {1}x{2} jpeg {3} KB" -f $i, $w, $h, [Math]::Round($bytes.Length / 1KB))
  $b64 = [Convert]::ToBase64String($bytes)

  $body = @{
    apikey           = "helloworld"
    language         = "rus"
    isOverlayRequired = "false"
    OCREngine        = "2"
    scale            = "true"
    base64Image      = "data:image/jpeg;base64,$b64"
  }

  $outFile = "C:\dev\gdz_app\tool\ocr_$i.json"
  try {
    $r = Invoke-WebRequest -Uri "https://api.ocr.space/parse/image" -Method Post -Body $body -TimeoutSec 180 -UseBasicParsing
    [System.IO.File]::WriteAllText($outFile, $r.Content, (New-Object System.Text.UTF8Encoding($false)))
    $parsed = $r.Content | ConvertFrom-Json
    if ($parsed.IsErroredOnProcessing) {
      Write-Host ("OCR error: " + ($parsed.ErrorMessage -join "; "))
    } else {
      Write-Host ("text chars: " + $parsed.ParsedResults[0].ParsedText.Length)
    }
  } catch {
    Write-Host ("request failed: " + $_.Exception.Message)
  }
}
