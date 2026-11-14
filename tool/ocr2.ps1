$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime

$code = @'
using System;
using Windows.Storage;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Globalization;

public static class OcrHelper
{
    public static string Run(string path)
    {
        var file = StorageFile.GetFileFromPathAsync(path).AsTask().GetAwaiter().GetResult();
        var stream = file.OpenAsync(FileAccessMode.Read).AsTask().GetAwaiter().GetResult();
        var decoder = BitmapDecoder.CreateAsync(stream).AsTask().GetAwaiter().GetResult();
        var bitmap = decoder.GetSoftwareBitmapAsync().AsTask().GetAwaiter().GetResult();
        var engine = OcrEngine.TryCreateFromLanguage(new Language("ru"));
        if (engine == null) throw new Exception("no ru OCR engine");
        var result = engine.RecognizeAsync(bitmap).AsTask().GetAwaiter().GetResult();
        stream.Dispose();
        return result.Text;
    }
}
'@

$winmd = 'C:\Windows\System32\WinMetadata'
Add-Type -TypeDefinition $code -ReferencedAssemblies @(
  "$winmd\Windows.Foundation.winmd",
  "$winmd\Windows.Storage.winmd",
  "$winmd\Windows.Graphics.winmd",
  "$winmd\Windows.Media.winmd",
  "$winmd\Windows.Globalization.winmd",
  'System.Runtime.WindowsRuntime.dll'
)

$files = @(
  'C:\Users\мира\Downloads\51a14238-274f-4803-bfaf-078fe8294086.jpg',
  'C:\Users\мира\Downloads\0e63ffa4-5813-46ad-8f29-641620fa6657.jpg',
  'C:\Users\мира\Downloads\ef934fc0-1772-49e6-9a76-346a95df1dde.jpg',
  'C:\Users\мира\Downloads\12ee08f8-ade0-4fa2-bd70-5acc7c080c08.jpg'
)

$out = @()
foreach ($f in $files) {
  $out += "===== $(Split-Path $f -Leaf) ====="
  if (-not (Test-Path $f)) { $out += 'MISSING'; continue }
  try { $out += [OcrHelper]::Run($f) } catch { $out += "OCR ERROR: $($_.Exception.Message)" }
}
[System.IO.File]::WriteAllLines('C:\dev\gdz_app\tool\ocr_result.txt', $out, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'done'
