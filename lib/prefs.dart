// Простое хранилище настроек без плагинов.
// На вебе — localStorage, на остальных платформах — JSON-файл в кэше.
// Плагин shared_preferences не используется: на Windows без режима
// разработчика Flutter не может создать симлинки для плагинов и сборка
// APK падает.
export 'prefs_io.dart' if (dart.library.js_interop) 'prefs_web.dart';
