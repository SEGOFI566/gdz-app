@echo off
setlocal
set PATH=C:\dev\git\cmd;%PATH%
cd /d C:\dev\gdz_app
set LOG=C:\dev\gdz_app\tool\commit.log
echo ==== commit start %DATE% %TIME% ==== > %LOG%

set /a tries=0
:wait
findstr /C:"publish done" C:\dev\gdz_app\tool\publish.log >nul 2>&1
if not errorlevel 1 goto go
findstr /C:"publish failed" C:\dev\gdz_app\tool\publish.log >nul 2>&1
if not errorlevel 1 goto go
findstr /C:"validation failed" C:\dev\gdz_app\tool\publish.log >nul 2>&1
if not errorlevel 1 goto go
set /a tries+=1
if %tries% GEQ 240 goto timeout
ping -n 31 127.0.0.1 >nul
goto wait

:go
echo ==== publish finished, committing ==== >> %LOG%
git add -A >> %LOG% 2>&1
git commit -F tool\commitmsg.txt >> %LOG% 2>&1
git push origin main >> %LOG% 2>&1
echo ==== commit exit=%ERRORLEVEL% ==== >> %LOG%
git log --oneline -2 >> %LOG% 2>&1
endlocal
exit /b 0

:timeout
echo ==== timeout waiting for publish ==== >> %LOG%
endlocal
exit /b 4
