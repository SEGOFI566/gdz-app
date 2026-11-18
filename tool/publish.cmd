@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;%PATH%
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_CACHE=C:\dev\pub-cache
cd /d C:\dev\gdz_app
set LOG=C:\dev\gdz_app\tool\publish.log
echo ==== publish start %DATE% %TIME% ==== > %LOG%

set /a tries=0
:wait
if exist C:\dev\gdz_app\tool\rebuild.log (
  findstr /C:"exit=" C:\dev\gdz_app\tool\rebuild.log >nul 2>&1
  if not errorlevel 1 goto rebuildfinished
)
set /a tries+=1
if %tries% GEQ 240 goto timeout
ping -n 31 127.0.0.1 >nul
goto wait

:rebuildfinished
findstr /C:"exit=0" C:\dev\gdz_app\tool\rebuild.log >nul 2>&1
if errorlevel 1 goto rebuildfailed

echo ==== rebuild done, validating ==== >> %LOG%
call C:\dev\flutter\bin\dart.bat tool\validate_catalog.dart >> %LOG% 2>&1
if errorlevel 1 goto invalid

echo ==== build apk ==== >> %LOG%
powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1 >> %LOG% 2>&1
if errorlevel 1 goto failed

echo ==== deploy pages ==== >> %LOG%
powershell -NoProfile -ExecutionPolicy Bypass -File tool\github_pages.ps1 -Owner SEGOFI566 -Repo gdz-app >> %LOG% 2>&1
if errorlevel 1 goto failed

echo ==== publish done ==== >> %LOG%
endlocal
exit /b 0

:rebuildfailed
echo ==== rebuild failed ==== >> %LOG%
endlocal
exit /b 2

:invalid
echo ==== validation failed ==== >> %LOG%
endlocal
exit /b 3

:timeout
echo ==== timeout waiting for rebuild ==== >> %LOG%
endlocal
exit /b 4

:failed
echo ==== publish failed ==== >> %LOG%
endlocal
exit /b 1
