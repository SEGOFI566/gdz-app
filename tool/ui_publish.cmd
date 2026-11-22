@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;%PATH%
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_CACHE=C:\dev\pub-cache
set GIT_SSL_NO_VERIFY=1
cd /d C:\dev\gdz_app
set LOG=C:\dev\gdz_app\tool\ui.log
echo ==== web publish start %DATE% %TIME% ==== > %LOG%
echo APK is NOT rebuilt or uploaded in this run. >> %LOG%

echo ==== analyze ==== >> %LOG%
call C:\dev\flutter\bin\dart.bat analyze lib --no-fatal-warnings >> %LOG% 2>&1
if errorlevel 1 goto failed

echo ==== deploy pages (web only) ==== >> %LOG%
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool\deploy_pages.ps1 -Owner SEGOFI566 -Repo gdz-app -ApkUrl "https://github.com/SEGOFI566/gdz-app/releases/download/v1.0.0/gdz-app.apk" >> %LOG% 2>&1
if errorlevel 1 goto failed

echo ==== commit ==== >> %LOG%
git add -A >> %LOG% 2>&1
git commit -m "data: real geometry 7-9 tasks (Atanasyan 2023-2026)" >> %LOG% 2>&1
git push origin main >> %LOG% 2>&1
echo ==== push exit=%ERRORLEVEL% ==== >> %LOG%

echo ==== web publish done ==== >> %LOG%
endlocal
exit /b 0

:failed
echo ==== web publish failed ==== >> %LOG%
endlocal
exit /b 1
