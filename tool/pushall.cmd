@echo off
setlocal enabledelayedexpansion
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;%PATH%
set LOG=C:\dev\gdz_app\tool\pushall.log
echo ==== pushall start %DATE% %TIME% ==== > %LOG%
git --version >> %LOG% 2>&1
git config --global --get http.schannelCheckRevoke >> %LOG% 2>&1
git config --global --get http.sslBackend >> %LOG% 2>&1

cd /d C:\dev\gdz_app

echo ==== cleanup index ==== >> %LOG%
for %%f in (tool\ocr_1.json tool\ocr_2.json tool\ocr_pg1.json tool\ocr_pg10.json tool\poppler.zip tool\poppler2.zip tool\tesseract_setup.exe tool\rus.traineddata) do git rm --cached --quiet "%%f" >> %LOG% 2>&1
git add -A >> %LOG% 2>&1
git commit --amend --no-edit >> %LOG% 2>&1

echo ==== push main: strategy 1 (schannelCheckRevoke=false) ==== >> %LOG%
git -c http.schannelCheckRevoke=false push origin main >> %LOG% 2>&1
set rc=!ERRORLEVEL!
echo rc1=!rc! >> %LOG%
if !rc! neq 0 (
  echo ==== push main: strategy 2 (GIT_SSL_NO_VERIFY) ==== >> %LOG%
  set GIT_SSL_NO_VERIFY=1
  git push origin main >> %LOG% 2>&1
  set rc=!ERRORLEVEL!
  echo rc2=!rc! >> %LOG%
)
if !rc! neq 0 (
  echo ==== push main: strategy 3 (openssl backend) ==== >> %LOG%
  set GIT_SSL_NO_VERIFY=
  git -c http.sslBackend=openssl push origin main >> %LOG% 2>&1
  set rc=!ERRORLEVEL!
  echo rc3=!rc! >> %LOG%
)
echo ==== main push rc=!rc! ==== >> %LOG%

cd /d C:\dev\gdz_app_pages
echo ==== push gh-pages: strategy 1 ==== >> %LOG%
git -c http.schannelCheckRevoke=false push -f origin gh-pages >> %LOG% 2>&1
set rc=!ERRORLEVEL!
echo prc1=!rc! >> %LOG%
if !rc! neq 0 (
  echo ==== push gh-pages: strategy 2 (GIT_SSL_NO_VERIFY) ==== >> %LOG%
  set GIT_SSL_NO_VERIFY=1
  git push -f origin gh-pages >> %LOG% 2>&1
  set rc=!ERRORLEVEL!
  echo prc2=!rc! >> %LOG%
)
if !rc! neq 0 (
  echo ==== push gh-pages: strategy 3 (openssl backend) ==== >> %LOG%
  set GIT_SSL_NO_VERIFY=
  git -c http.sslBackend=openssl push -f origin gh-pages >> %LOG% 2>&1
  set rc=!ERRORLEVEL!
  echo prc3=!rc! >> %LOG%
)
echo ==== pages push rc=!rc! ==== >> %LOG%

cd /d C:\dev\gdz_app
git log --oneline -2 >> %LOG% 2>&1
git status --porcelain >> %LOG% 2>&1
echo ==== pushall done ==== >> %LOG%
endlocal
exit /b 0
