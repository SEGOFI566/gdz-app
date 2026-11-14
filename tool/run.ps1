param(
  [string]$Device = "chrome"
)

# В этой сети серверы Google и pub.dev недоступны напрямую,
# поэтому используем официальное китайское зеркало Flutter.
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

Write-Host "Устройство: $Device" -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter run -d $Device
