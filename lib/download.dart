// Открывает ссылку на скачивание APK.
// На вебе используется window.open, на остальных платформах — заглушка
// (кнопка показывается только в веб-версии).
export 'download_stub.dart'
    if (dart.library.js_interop) 'download_web.dart';
