@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\flutter\bin;%PATH%
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_CACHE=C:\dev\pub-cache
cd /d C:\dev\gdz_app
echo start %DATE% %TIME% > C:\dev\gdz_app\tool\rebuild.log
call C:\dev\flutter\bin\dart.bat tool\rebuild_barkhudarov.dart assets\data\catalog.json >> C:\dev\gdz_app\tool\rebuild.log 2>&1
echo exit=%ERRORLEVEL% >> C:\dev\gdz_app\tool\rebuild.log
endlocal
