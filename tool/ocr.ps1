$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await($WinRtTask, $ResultType) {
  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
  $netTask = $asTask.Invoke($null, @($WinRtTask))
  $netTask.Wait(-1) | Out-Null
  $netTask.Result
}

$lang = New-Object Windows.Globalization.Language 'ru'
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang)
if (-not $engine) { throw 'Russian OCR engine unavailable' }

$dir = 'C:\Users\мира\Downloads'
$files = Get-ChildItem $dir -Filter *.jpg | Where-Object {
  $_.Name -in @(
    '51a14238-274f-4803-bfaf-078fe8294086.jpg',
    '0e63ffa4-5813-46ad-8f29-641620fa6657.jpg',
    'ef934fc0-1772-49e6-9a76-346a95df1dde.jpg',
    '12ee08f8-ade0-4fa2-bd70-5acc7c080c08.jpg'
  )
}

$out = @()
foreach ($f in $files) {
  $out += "===== $($f.Name) ====="
  try {
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($f.FullName)) ([Windows.Storage.StorageFile])
    $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    foreach ($line in $result.Lines) { $out += $line.Text }
    $stream.Dispose()
  } catch {
    $out += "OCR ERROR: $($_.Exception.Message)"
  }
}

$outPath = 'C:\dev\gdz_app\tool\ocr_result.txt'
[System.IO.File]::WriteAllLines($outPath, $out, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "written: $outPath lines=$($out.Count)"
