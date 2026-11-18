$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$files = @(
  (Join-Path $env:USERPROFILE "Downloads\12ee08f8-ade0-4fa2-bd70-5acc7c080c08.jpg"),
  (Join-Path $env:USERPROFILE "Downloads\51a14238-274f-4803-bfaf-078fe8294086.jpg")
)

$i = 0
foreach ($f in $files) {
  $i++
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
  $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ps = New-Object System.Drawing.Imaging.EncoderParameters 1
  $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]90)
  $dst = "C:\dev\gdz_app\tool\ocr_src_$i.jpg"
  $bmp.Save($dst, $enc, $ps)
  $bmp.Dispose()
  $img.Dispose()
  Write-Host ("saved {0} {1}x{2} {3} KB" -f $dst, $w, $h, [Math]::Round((Get-Item $dst).Length / 1KB))
}
