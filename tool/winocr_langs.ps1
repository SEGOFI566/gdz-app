$ErrorActionPreference = "Stop"
try {
  [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
  $langs = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
  foreach ($l in $langs) { Write-Host ("lang: " + $l.LanguageTag) }
} catch {
  Write-Host ("winocr error: " + $_.Exception.Message)
}
