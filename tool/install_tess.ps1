$ErrorActionPreference = "Stop"
$setup = "C:\dev\gdz_app\tool\tesseract_setup.exe"
$target = "C:\dev\tesseract"
$p = Start-Process -FilePath $setup -ArgumentList "/S /D=$target" -Wait -PassThru
Write-Host ("exit: " + $p.ExitCode)
if (Test-Path (Join-Path $target "tesseract.exe")) {
  Write-Host "installed: $target\tesseract.exe"
} else {
  Write-Host "not installed"
}
if (Test-Path "C:\dev\gdz_app\tool\rus.traineddata") {
  Copy-Item "C:\dev\gdz_app\tool\rus.traineddata" (Join-Path $target "tessdata\rus.traineddata") -Force
  Write-Host "rus.traineddata copied"
}
