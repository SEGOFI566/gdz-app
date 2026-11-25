import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'prefs.dart';

/// Глобальное состояние приложения: каталог, выбранный класс, избранное.
class AppState extends ChangeNotifier {
  static const _gradeKey = 'selected_grade';
  static const _favoritesKey = 'favorite_task_ids';
  static const _recentKey = 'recent_task_ids';
  static const _recentLimit = 20;

  Catalog? catalog;
  bool loading = true;
  String? error;
  int grade = 5;

  final List<String> _favorites = [];
  final List<String> _recent = [];

  List<String> get favorites => List.unmodifiable(_favorites);
  List<String> get recent => List.unmodifiable(_recent);

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
      final savedRecent = prefs.getStringList(_recentKey);
      if (savedRecent != null) {
        _recent.addAll(
          savedRecent.where((id) => catalog!.taskById.containsKey(id)),
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

  List<TaskItem> get recentTasks {
    final data = catalog;
    if (data == null) return const [];
    return _recent
        .map((id) => data.taskById[id])
        .whereType<TaskItem>()
        .toList();
  }

  Future<void> markRecent(String taskId) async {
    final data = catalog;
    if (data == null || !data.taskById.containsKey(taskId)) return;
    _recent.remove(taskId);
    _recent.insert(0, taskId);
    if (_recent.length > _recentLimit) {
      _recent.removeRange(_recentLimit, _recent.length);
    }
    notifyListeners();
    final prefs = await AppPrefs.getInstance();
    await prefs.setStringList(_recentKey, _recent);
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

  /// Достаёт номер задания из запроса вида «527», «№ 527», «задание 527».
  static String? numberQuery(String query) {
    final match = RegExp(
      r'^\s*(?:№|номер|задание|no\.?)?\s*(\d{1,4})\s*$',
      caseSensitive: false,
    ).firstMatch(query);
    return match?.group(1);
  }

  /// Поиск по всему каталогу. Точные совпадения номера идут первыми,
  /// затем номера, содержащие запрос, затем совпадения по тексту.
  /// Можно ограничить поиск классом, предметом или учебником.
  List<TaskItem> search(
    String query, {
    int limit = 50,
    int? grade,
    String? subjectId,
    String? textbookId,
  }) {
    final data = catalog;
    final text = query.trim().toLowerCase();
    if (data == null || text.isEmpty) return const [];

    bool matchesFilters(TaskItem task) {
      final textbook = data.textbookById[task.textbookId];
      if (textbook == null) return false;
      if (textbookId != null && textbook.id != textbookId) return false;
      if (subjectId != null && textbook.subjectId != subjectId) return false;
      if (grade != null && textbook.grade != grade) return false;
      return true;
    }

    final number = numberQuery(text);
    final exact = <TaskItem>[];
    final byNumber = <TaskItem>[];
    final byText = <TaskItem>[];

    for (final task in data.tasks) {
      if (!matchesFilters(task)) continue;
      if (number != null && task.number == number) {
        exact.add(task);
        continue;
      }
      if (task.number.contains(number ?? text)) {
        byNumber.add(task);
        continue;
      }
      if (number != null) continue;
      final textbook = data.textbookById[task.textbookId];
      final subject =
          textbook == null ? null : data.subjectById[textbook.subjectId];
      final matches = task.condition.toLowerCase().contains(text) ||
          (textbook?.title.toLowerCase().contains(text) ?? false) ||
          (textbook?.author.toLowerCase().contains(text) ?? false) ||
          (subject?.name.toLowerCase().contains(text) ?? false);
      if (matches) byText.add(task);
    }
    return [...exact, ...byNumber, ...byText].take(limit).toList();
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
