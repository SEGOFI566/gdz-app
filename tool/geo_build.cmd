@echo off
chcp 65001 >nul
title Геометрия 8 - сборка заданий (Атанасян 2023-2026)
setlocal
set PATH=C:\dev\git\cmd;C:\dev\gh\bin;C:\dev\flutter\bin;%PATH%
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_CACHE=C:\dev\pub-cache
cd /d C:\dev\gdz_app

echo ============================================================
echo   Сборка реальных заданий по геометрии, 8 класс
echo   Источники: budu5.com, gdz.ru, reshak.ru
echo   Займет 10-20 минут. Окно закрывать нельзя.
echo ============================================================
echo.

if not exist assets\data\catalog.json goto nocatalog
copy /y assets\data\catalog.json tool\catalog_before_geo.json >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { & 'C:\dev\flutter\bin\dart.bat' 'tool\rebuild_geometry8.dart' 2>&1 | Tee-Object -FilePath 'tool\geo_build.log'; Write-Host ''; Write-Host '--- проверка каталога ---'; & 'C:\dev\flutter\bin\dart.bat' 'tool\validate_catalog.dart' 2>&1 | Tee-Object -FilePath 'tool\geo_build.log' -Append }"

echo.
echo ============================================================
echo   Готово. Отчет: tool\geometry8_report.txt
echo ============================================================
pause
exit /b 0

:nocatalog
echo ОШИБКА: не найден assets\data\catalog.json
echo Проверьте, что папка C:\dev\gdz_app на месте.
pause
exit /b 1
