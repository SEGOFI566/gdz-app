@echo off
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;%PATH%
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_CACHE=C:\dev\pub-cache
cd /d C:\dev\gdz_app
set LOG=tool\geo_crawl.log
echo === start %DATE% %TIME% === > %LOG%
C:\dev\flutter\bin\dart.bat tool\rebuild_geometry8.dart --dry >> %LOG% 2>&1
echo === exit %ERRORLEVEL% %DATE% %TIME% === >> %LOG%
