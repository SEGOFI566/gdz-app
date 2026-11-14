import 'dart:js_interop';

@JS('open')
external void _open(String url, String target);

/// Открывает ссылку на APK в текущей вкладке — браузер скачает файл.
void openApkDownload(String url) => _open(url, '_self');
