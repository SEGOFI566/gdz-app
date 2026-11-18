// Replaces the Barkhudarov textbook tasks in the catalog with real data.
//
// Usage:
//   dart tool/apply_tasks.dart <catalog.json> <tasks.json> [--write]
//
// tasks.json format:
//   [
//     {
//       "number": 1,
//       "page": 5,
//       "condition": "...",
//       "steps": ["...", "..."],
//       "answer": "..."
//     }
//   ]
//
// Without --write the script only validates and prints statistics.
import 'dart:convert';
import 'dart:io';

const textbookId = 'russian-8-barkhudarov';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: apply_tasks <catalog.json> <tasks.json> [--write]');
    exit(1);
  }
  final write = args.contains('--write');
  final catalogFile = File(args[0]);
  final tasksFile = File(args[1]);

  final catalog = _readJson(catalogFile) as Map<String, dynamic>;
  final raw = _readJson(tasksFile) as List;

  final tasks = <Map<String, dynamic>>[];
  final seen = <int>{};
  for (final e in raw) {
    final m = e as Map<String, dynamic>;
    final number = (m['number'] as num).toInt();
    if (!seen.add(number)) {
      stderr.writeln('duplicate exercise number: $number');
      exit(2);
    }
    final condition = (m['condition'] as String? ?? '').trim();
    if (condition.isEmpty) {
      stderr.writeln('empty condition for $number');
      exit(2);
    }
    final steps = (m['steps'] as List? ?? const []).map((x) => '$x').toList();
    final answer = (m['answer'] as String? ?? '').trim();
    if (steps.isEmpty || answer.isEmpty) {
      stderr.writeln('missing solution for $number');
      exit(2);
    }
    tasks.add({
      'id': '$textbookId-$number',
      'textbookId': textbookId,
      'number': '$number',
      'page': (m['page'] as num).toInt(),
      'condition': condition,
      'solutions': [
        {
          'id': '$textbookId-$number-s1',
          'author': m['author'] ?? 'Команда ГДЗ',
          'rating': m['rating'] ?? 4.8,
          'steps': steps,
          'answer': answer,
        }
      ],
    });
  }
  tasks.sort((a, b) =>
      int.parse(a['number'] as String).compareTo(int.parse(b['number'] as String)));

  final all = (catalog['tasks'] as List).cast<Map<String, dynamic>>();
  final kept = all.where((t) => t['textbookId'] != textbookId).toList();
  final removed = all.length - kept.length;
  catalog['tasks'] = [...kept, ...tasks];

  stdout.writeln('removed: $removed');
  stdout.writeln('added: ${tasks.length}');
  stdout.writeln('total tasks: ${catalog['tasks'].length}');
  final pages = tasks.map((t) => t['page'] as int).toList()..sort();
  stdout.writeln('page range: ${pages.first}..${pages.last}');
  stdout.writeln('exercises: ${tasks.map((t) => t['number']).join(', ')}');

  if (write) {
    final out = const JsonEncoder.withIndent('    ').convert(catalog);
    catalogFile.writeAsStringSync('$out\n');
    stdout.writeln('written: ${catalogFile.path}');
  } else {
    stdout.writeln('dry run (pass --write to update the catalog)');
  }
}

dynamic _readJson(File file) {
  var text = file.readAsStringSync();
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  return jsonDecode(text);
}
