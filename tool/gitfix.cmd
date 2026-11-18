@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;%PATH%
cd /d C:\dev\gdz_app
set LOG=C:\dev\gdz_app\tool\gitfix.log
echo ==== gitfix start %DATE% %TIME% ==== > %LOG%

set /a tries=0
:wait
if exist tool\fix.log (
  findstr /C:"fix publish done" tool\fix.log >nul 2>&1
  if not errorlevel 1 goto go
  findstr /C:"validation failed" tool\fix.log >nul 2>&1
  if not errorlevel 1 goto go
  findstr /C:"fix publish failed" tool\fix.log >nul 2>&1
  if not errorlevel 1 goto go
)
set /a tries+=1
if %tries% GEQ 240 goto timeout
ping -n 31 127.0.0.1 >nul
goto wait

:go
echo ==== untrack scan/OCR artifacts ==== >> %LOG%
git rm -r --cached --quiet tool\img2011 tool\pages tool\ocr_margin tool\ocr_marg2 tool\ocr_pages tool\ocr_s3 >> %LOG% 2>&1
git rm --cached --quiet tool\ocr_1.json tool\ocr_2.json tool\ocr_pg1.json tool\ocr_pg10.json tool\poppler.zip tool\poppler2.zip tool\tesseract_setup.exe tool\rus.traineddata tool\map_partial.json >> %LOG% 2>&1
for %%f in (tool\pg-*.jpg tool\ocr_src_*.jpg) do git rm --cached --quiet "%%f" >> %LOG% 2>&1

echo ==== amend commit ==== >> %LOG%
git add -A >> %LOG% 2>&1
git commit --amend -F tool\commitmsg.txt >> %LOG% 2>&1

echo ==== push ==== >> %LOG%
git -c http.schannelCheckRevoke=false push origin main >> %LOG% 2>&1
if errorlevel 1 git -c http.sslBackend=openssl push origin main >> %LOG% 2>&1
echo ==== push exit=%ERRORLEVEL% ==== >> %LOG%
git log --oneline -2 >> %LOG% 2>&1
git status --porcelain >> %LOG% 2>&1
endlocal
exit /b 0

:timeout
echo ==== timeout waiting for fix job ==== >> %LOG%
endlocal
exit /b 4
