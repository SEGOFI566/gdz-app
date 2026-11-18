@echo off
curl.exe -s -X POST "https://api.ocr.space/parse/image" -F "apikey=helloworld" -F "language=rus" -F "OCREngine=2" -F "scale=true" -F "isOverlayRequired=false" -F "file=@C:\dev\gdz_app\tool\pg-001.jpg" -o "C:\dev\gdz_app\tool\ocr_pg1.json"
curl.exe -s -X POST "https://api.ocr.space/parse/image" -F "apikey=helloworld" -F "language=rus" -F "OCREngine=2" -F "scale=true" -F "isOverlayRequired=false" -F "file=@C:\dev\gdz_app\tool\pg-010.jpg" -o "C:\dev\gdz_app\tool\ocr_pg10.json"
echo done
