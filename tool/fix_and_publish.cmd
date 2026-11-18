@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;%PATH%
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_CACHE=C:\dev\pub-cache
cd /d C:\dev\gdz_app
set LOG=C:\dev\gdz_app\tool\fix.log
echo ==== fix start %DATE% %TIME% ==== > %LOG%

echo ==== rebuild from dump ==== >> %LOG%
call C:\dev\flutter\bin\dart.bat tool\rebuild_barkhudarov.dart assets\data\catalog.json --from-dump >> %LOG% 2>&1
if errorlevel 1 goto failed

echo ==== validating ==== >> %LOG%
call C:\dev\flutter\bin\dart.bat tool\validate_catalog.dart >> %LOG% 2>&1
if errorlevel 1 goto invalid

echo ==== build apk ==== >> %LOG%
powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1 >> %LOG% 2>&1
if errorlevel 1 goto failed

echo ==== deploy pages ==== >> %LOG%
powershell -NoProfile -ExecutionPolicy Bypass -File tool\github_pages.ps1 -Owner SEGOFI566 -Repo gdz-app >> %LOG% 2>&1
if errorlevel 1 goto failed

echo ==== fix publish done ==== >> %LOG%
endlocal
exit /b 0

:invalid
echo ==== validation failed ==== >> %LOG%
endlocal
exit /b 3

:failed
echo ==== fix publish failed ==== >> %LOG%
endlocal
exit /b 1
