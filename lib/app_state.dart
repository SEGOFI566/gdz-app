import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'prefs.dart';

/// Глобальное состояние приложения: каталог, выбранный класс, избранное.
class AppState extends ChangeNotifier {
  static const _gradeKey = 'selected_grade';
  static const _favoritesKey = 'favorite_task_ids';

  Catalog? catalog;
  bool loading = true;
  String? error;
  int grade = 5;

  final List<String> _favorites = [];

  List<String> get favorites => List.unmodifiable(_favorites);

  Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/data/catalog.json');
      catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      final prefs = await AppPrefs.getInstance();
      final savedGrade = prefs.getInt(_gradeKey);
      if (savedGrade != null && savedGrade >= 5 && savedGrade <= 11) {
        grade = savedGrade;
      }
      final savedFavorites = prefs.getStringList(_favoritesKey);
      if (savedFavorites != null) {
        _favorites.addAll(
          savedFavorites.where((id) => catalog!.taskById.containsKey(id)),
        );
      }
    } catch (e) {
      error = 'Не удалось загрузить каталог: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setGrade(int value) async {
    if (grade == value) return;
    grade = value;
    notifyListeners();
    final prefs = await AppPrefs.getInstance();
    await prefs.setInt(_gradeKey, value);
  }

  bool isFavorite(String taskId) => _favorites.contains(taskId);

  Future<void> toggleFavorite(String taskId) async {
    if (_favorites.contains(taskId)) {
      _favorites.remove(taskId);
    } else {
      _favorites.add(taskId);
    }
    notifyListeners();
    final prefs = await AppPrefs.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites);
  }

  List<TaskItem> get favoriteTasks {
    final data = catalog;
    if (data == null) return const [];
    return _favorites
        .map((id) => data.taskById[id])
        .whereType<TaskItem>()
        .toList();
  }

  List<Subject> subjectsForGrade(int value) =>
      catalog?.subjectsForGrade(value) ?? const [];

  List<Textbook> textbooksFor(String subjectId, int value) =>
      catalog?.textbooksFor(subjectId, value) ?? const [];

  List<TaskItem> tasksFor(String textbookId) =>
      catalog?.tasksFor(textbookId) ?? const [];

  Textbook? textbookById(String id) => catalog?.textbookById[id];

  Subject? subjectById(String id) => catalog?.subjectById[id];

  TaskItem? taskById(String id) => catalog?.taskById[id];

  int taskCountForSubject(String subjectId, int value) {
    final data = catalog;
    if (data == null) return 0;
    var total = 0;
    for (final textbook in data.textbooksFor(subjectId, value)) {
      total += data.taskCountFor(textbook.id);
    }
    return total;
  }

  List<TaskItem> search(String query) {
    final data = catalog;
    final text = query.trim().toLowerCase();
    if (data == null || text.isEmpty) return const [];

    final results = <TaskItem>[];
    for (final task in data.tasks) {
      final textbook = data.textbookById[task.textbookId];
      final subject =
          textbook == null ? null : data.subjectById[textbook.subjectId];
      final matches = task.number.toLowerCase().contains(text) ||
          task.condition.toLowerCase().contains(text) ||
          (textbook?.title.toLowerCase().contains(text) ?? false) ||
          (textbook?.author.toLowerCase().contains(text) ?? false) ||
          (subject?.name.toLowerCase().contains(text) ?? false);
      if (matches) results.add(task);
      if (results.length >= 50) break;
    }
    return results;
  }
}

/// Даёт доступ к [AppState] и перестраивает зависимые виджеты при изменениях.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден в дереве виджетов');
    return scope!.notifier!;
  }
}
