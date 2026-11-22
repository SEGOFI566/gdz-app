$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime

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

[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Media, ContentType = WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null

$files = @(
  'C:\Users\мира\Downloads\ef934fc0-1772-49e6-9a76-346a95df1dde.jpg',
  'C:\Users\мира\Downloads\ea211152-da9f-4e70-b524-7ef8f77dc797.jpg'
)

$out = New-Object System.Collections.Generic.List[string]
foreach ($f in $files) {
  $out.Add("===== $(Split-Path $f -Leaf) =====")
  if (-not (Test-Path -LiteralPath $f)) { $out.Add('MISSING'); continue }
  try {
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($f)) ([Windows.Storage.StorageFile])
    $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('ru'))
    if ($null -eq $engine) { $out.Add('NO RU OCR ENGINE'); continue }
    $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $out.Add($result.Text)
    $stream.Dispose()
  } catch {
    $out.Add("OCR ERROR: $($_.Exception.Message)")
  }
}

[System.IO.File]::WriteAllLines('C:\dev\gdz_app\tool\ocr_attached.txt', $out, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'done'
