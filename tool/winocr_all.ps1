param(
  [string]$ImageDir = "C:\dev\gdz_app\tool\img2022",
  [string]$OutDir = "C:\dev\gdz_app\tool\ocr_pages",
  [int]$From = 1,
  [int]$To = 0,
  [double]$Scale = 2.0
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime

[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  })[0]

function Await($WinRtTask, $ResultType) {
  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
  $netTask = $asTask.Invoke($null, @($WinRtTask))
  $netTask.Wait(-1) | Out-Null
  $netTask.Result
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory $OutDir | Out-Null }

$lang = New-Object Windows.Globalization.Language "ru"
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang)
if ($null -eq $engine) { throw "no ru OCR engine" }

$files = Get-ChildItem $ImageDir -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png)$' } | Sort-Object Name
if ($To -le 0) { $To = $files.Count }
Write-Host ("images: " + $files.Count + " range " + $From + ".." + $To)

$tmp = Join-Path $env:TEMP "winocr_scaled.png"
$i = 0
$done = 0
foreach ($f in $files) {
  $i++
  if ($i -lt $From -or $i -gt $To) { continue }
  $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $outTxt = Join-Path $OutDir ($base + ".txt")
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

  $sf = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile])
  $stream = Await ($sf.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $sb = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  $res = Await ($engine.RecognizeAsync($sb)) ([Windows.Media.Ocr.OcrResult])
  $stream.Dispose()

  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $res.Lines) { $lines.Add($ln.Text) }
  [System.IO.File]::WriteAllText($outTxt, ($lines -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
  $done++
  if ($done % 10 -eq 0) { Write-Host ("done " + $done + " (page " + $i + ")") }
}
Write-Host ("finished, wrote " + $done)
