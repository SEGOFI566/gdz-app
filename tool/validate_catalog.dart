// Validates the catalog before publishing.
//
// Usage: dart tool/validate_catalog.dart [catalog.json]
// Exit code 1 means the catalog must not be published.
import 'dart:convert';
import 'dart:io';

const _junk = [
  'учебника 20',
  'Скачан с',
  '&nbsp',
  '&#',
  'Страница ',
  'Выберите год',
  'Вернуться к содержанию',
];

/// Textbooks that must contain real data, with the minimum task count we
/// accept for them.
const _required = <String, int>{
  'russian-8-barkhudarov': 500,
  'geometry-8': 400,
};

bool _hasShareLine(String text) =>
    text.split('\n').any((line) => line.trim() == 'Поделиться');

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : 'assets/data/catalog.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('catalog not found: $path');
    exit(1);
  }
  final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final tasks = (catalog['tasks'] as List).cast<Map<String, dynamic>>();
  final textbooks =
      (catalog['textbooks'] as List).cast<Map<String, dynamic>>();

  final problems = <String>[];
  final ids = <String>{};
  for (final task in tasks) {
    final id = task['id'] as String? ?? '';
    if (id.isEmpty) {
      problems.add('task without id');
    } else if (!ids.add(id)) {
      problems.add('duplicate task id: $id');
    }
  }

  final failing = <String>{};
  var taskTotal = 0;
  var pageRegressions = 0;

  for (final entry in _required.entries) {
    final textbookId = entry.key;
    final minimum = entry.value;

    final textbook = textbooks.where((t) => t['id'] == textbookId).toList();
    if (textbook.isEmpty) {
      problems.add('textbook $textbookId is missing');
      failing.add(textbookId);
      continue;
    }

    final own = tasks.where((t) => t['textbookId'] == textbookId).toList();
    taskTotal += own.length;
    final numbers = <int>[];
    var lastPage = 0;
    for (final task in own) {
      final rawNumber = '${task['number']}';
      final number = int.tryParse(rawNumber);
      if (number == null) {
        problems.add('$textbookId: bad number: $rawNumber');
        continue;
      }
      numbers.add(number);
      final page = (task['page'] as num?)?.toInt() ?? 0;
      if (page < 1) problems.add('$textbookId $number: bad page $page');
      if (page + 2 < lastPage) pageRegressions++;
      lastPage = page > lastPage ? page : lastPage;

      final condition = '${task['condition'] ?? ''}';
      if (condition.trim().length < 20) {
        problems.add('$textbookId $number: condition too short');
      }
      for (final junk in _junk) {
        if (condition.contains(junk)) {
          problems.add('$textbookId $number: junk in condition ($junk)');
        }
      }
      if (_hasShareLine(condition)) {
        problems.add('$textbookId $number: share widget in condition');
      }
      final solutions = (task['solutions'] as List?) ?? const [];
      if (solutions.isEmpty) {
        problems.add('$textbookId $number: no solution');
        continue;
      }
      final solution = solutions.first as Map<String, dynamic>;
      final steps = (solution['steps'] as List?) ?? const [];
      final answer = '${solution['answer'] ?? ''}';
      if (steps.isEmpty) problems.add('$textbookId $number: no steps');
      if (answer.trim().isEmpty) {
        problems.add('$textbookId $number: empty answer');
      }
      for (final step in steps) {
        final text = '$step';
        if (text.trim().isEmpty) {
          problems.add('$textbookId $number: empty step');
        }
        for (final junk in _junk) {
          if (text.contains(junk)) {
            problems.add('$textbookId $number: junk in step ($junk)');
          }
        }
        if (_hasShareLine(text)) {
          problems.add('$textbookId $number: share widget in step');
        }
      }
      for (final junk in _junk) {
        if (answer.contains(junk)) {
          problems.add('$textbookId $number: junk in answer ($junk)');
        }
      }
      if (_hasShareLine(answer)) {
        problems.add('$textbookId $number: share widget in answer');
      }
    }

    numbers.sort();
    final gaps = <String>[];
    for (var i = 1; i < numbers.length; i++) {
      if (numbers[i] - numbers[i - 1] > 1) {
        gaps.add('${numbers[i - 1] + 1}..${numbers[i] - 1}');
      }
    }
    final pages = own
        .map((t) => (t['page'] as num?)?.toInt() ?? 0)
        .where((p) => p > 0)
        .toList()
      ..sort();

    stdout.writeln('$textbookId: ${own.length} tasks, '
        'numbers ${numbers.isEmpty ? '-' : '${numbers.first}..${numbers.last}'}, '
        'pages ${pages.isEmpty ? '-' : '${pages.first}..${pages.last}'}');
    stdout.writeln('  gaps: ${gaps.isEmpty ? 'none' : gaps.join(', ')}');

    if (own.length < minimum) {
      problems.add('$textbookId: only ${own.length} tasks (need $minimum)');
      failing.add(textbookId);
    }
  }

  stdout.writeln('tasks total: ${tasks.length}');
  stdout.writeln('tasks in checked textbooks: $taskTotal');
  stdout.writeln('textbooks: ${textbooks.length}');
  stdout.writeln('page regressions: $pageRegressions');
  stdout.writeln('problems: ${problems.length}');
  for (final problem in problems.take(40)) {
    stdout.writeln('  - $problem');
  }

  if (problems.isNotEmpty || failing.isNotEmpty) {
    stderr.writeln('VALIDATION FAILED');
    exit(1);
  }
  stdout.writeln('VALIDATION OK');
}
