import 'dart:convert';

import 'dart:html' as html;

/// Хранилище настроек в localStorage браузера.
class AppPrefs {
  AppPrefs._();

  static AppPrefs? _instance;

  static Future<AppPrefs> getInstance() async =>
      _instance ??= AppPrefs._();

  String? _get(String key) => html.window.localStorage[key];

  void _set(String key, String value) {
    html.window.localStorage[key] = value;
  }

  int? getInt(String key) => int.tryParse(_get(key) ?? '');

  Future<void> setInt(String key, int value) async => _set(key, '$value');

  List<String>? getStringList(String key) {
    final raw = _get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> setStringList(String key, List<String> value) async =>
      _set(key, jsonEncode(value));
}
