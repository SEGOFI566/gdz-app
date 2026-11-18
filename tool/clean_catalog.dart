// Removes the site share widget text ("Поделиться") that leaked into some
// Barkhudarov tasks, without re-crawling the source.
//
// Usage: dart tool/clean_catalog.dart [catalog.json]
import 'dart:convert';
import 'dart:io';

const _textbookId = 'russian-8-barkhudarov';

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : 'assets/data/catalog.json';
  final file = File(path);
  final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final tasks = (catalog['tasks'] as List).cast<Map<String, dynamic>>();

  var fixedFields = 0;
  final touched = <String>[];

  String cut(String value) {
    final at = value.indexOf('Поделиться');
    if (at < 0) return value;
    final lineStart = at == 0 || value[at - 1] == '\n';
    final tail = value.substring(at);
    // Only the site's share widget is junk: either a standalone line, or
    // followed by the page navigation footer. A real condition may contain
    // "Поделиться с кем, чем" as a word to work with.
    final isWidget = (lineStart && !tail.contains(' с ')) ||
        tail.contains('Вернуться к содержанию');
    if (!isWidget) return value;
    fixedFields++;
    return value.substring(0, at).trimRight();
  }

  for (final task in tasks) {
    if (task['textbookId'] != _textbookId) continue;
    var changed = false;

    final condition = cut('${task['condition'] ?? ''}');
    if (condition != task['condition']) {
      task['condition'] = condition;
      changed = true;
    }

    final solutions = (task['solutions'] as List?) ?? const [];
    for (final raw in solutions) {
      final solution = raw as Map<String, dynamic>;
      final originalSteps = ((solution['steps'] as List?) ?? const [])
          .map((step) => '$step')
          .toList();
      final steps = originalSteps
          .map(cut)
          .where((step) => step.trim().isNotEmpty)
          .toList();
      if (steps.join() != originalSteps.join()) {
        solution['steps'] = steps;
        changed = true;
      }
      final answer = cut('${solution['answer'] ?? ''}');
      if (answer != solution['answer']) {
        solution['answer'] = answer;
        changed = true;
      }
    }

    if (changed) touched.add('${task['number']}');
  }

  if (fixedFields > 0) {
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(catalog)}\n',
    );
  }
  stdout.writeln('tasks touched: ${touched.length}');
  stdout.writeln('fields cleaned: $fixedFields');
  stdout.writeln('numbers: ${touched.join(', ')}');
  stdout.writeln(fixedFields > 0 ? 'catalog written' : 'nothing to clean');
}
