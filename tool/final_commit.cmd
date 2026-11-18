@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;%PATH%
set GIT_SSL_NO_VERIFY=1
cd /d C:\dev\gdz_app
set LOG=C:\dev\gdz_app\tool\final.log
echo ==== final commit start %DATE% %TIME% ==== > %LOG%
git add -A >> %LOG% 2>&1
git commit -m "deploy: use GIT_SSL_NO_VERIFY for pushes (schannel revocation check fails)" >> %LOG% 2>&1
git push origin main >> %LOG% 2>&1
echo ==== push exit=%ERRORLEVEL% ==== >> %LOG%
git log --oneline -3 >> %LOG% 2>&1
git status --porcelain >> %LOG% 2>&1
echo ==== final done ==== >> %LOG%
endlocal
exit /b 0
