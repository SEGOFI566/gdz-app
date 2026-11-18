@echo off
echo start %DATE% %TIME% > C:\dev\gdz_app\tool\ocr_run2.log
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\gdz_app\tool\winocr_all.ps1 -Scale 2.5 -OutDir C:\dev\gdz_app\tool\ocr25 >> C:\dev\gdz_app\tool\ocr_run2.log 2>&1
echo exit=%ERRORLEVEL% >> C:\dev\gdz_app\tool\ocr_run2.log
