@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;%PATH%
set LOG=C:\dev\gdz_app\tool\pushpages.log
echo ==== push pages start %DATE% %TIME% ==== > %LOG%
git config --global http.schannelCheckRevoke false
cd /d C:\dev\gdz_app_pages
git -c http.schannelCheckRevoke=false push -f origin gh-pages >> %LOG% 2>&1
if errorlevel 1 git -c http.sslBackend=openssl push -f origin gh-pages >> %LOG% 2>&1
echo ==== push exit=%ERRORLEVEL% ==== >> %LOG%
git log --oneline -1 >> %LOG% 2>&1
endlocal
exit /b 0
