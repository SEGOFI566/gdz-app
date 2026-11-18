@echo off
curl.exe -s -X POST "https://api.ocr.space/parse/image" -F "apikey=helloworld" -F "language=rus" -F "OCREngine=2" -F "scale=true" -F "isOverlayRequired=false" -F "file=@C:\dev\gdz_app\tool\ocr_src_1.jpg" -o "C:\dev\gdz_app\tool\ocr_1.json"
curl.exe -s -X POST "https://api.ocr.space/parse/image" -F "apikey=helloworld" -F "language=rus" -F "OCREngine=2" -F "scale=true" -F "isOverlayRequired=false" -F "file=@C:\dev\gdz_app\tool\ocr_src_2.jpg" -o "C:\dev\gdz_app\tool\ocr_2.json"
echo done
