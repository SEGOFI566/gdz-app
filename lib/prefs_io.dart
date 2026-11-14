import 'dart:convert';
import 'dart:io';

/// Хранилище настроек в JSON-файле внутри кэша приложения.
class AppPrefs {
  AppPrefs._(this._file, this._data);

  static AppPrefs? _instance;

  final File _file;
  final Map<String, dynamic> _data;

  static Future<AppPrefs> getInstance() async {
    final cached = _instance;
    if (cached != null) return cached;

    final dir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}gdz_app',
    );
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}prefs.json');

    Map<String, dynamic> data = <String, dynamic>{};
    if (await file.exists()) {
      try {
        data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        // Повреждённый файл просто игнорируем.
      }
    }
    return _instance = AppPrefs._(file, data);
  }

  int? getInt(String key) {
    final value = _data[key];
    return value is num ? value.toInt() : null;
  }

  Future<void> setInt(String key, int value) async {
    _data[key] = value;
    await _save();
  }

  List<String>? getStringList(String key) {
    final value = _data[key];
    if (value is! List) return null;
    return value.whereType<String>().toList();
  }

  Future<void> setStringList(String key, List<String> value) async {
    _data[key] = value;
    await _save();
  }

  Future<void> _save() async {
    await _file.writeAsString(jsonEncode(_data));
  }
}
