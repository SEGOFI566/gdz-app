// Builds real history tasks from budu5.com for the textbooks shown in the
// attached screenshots (8 class world history, 9 class Russia/world history).
//
// Only tasks with a real textual condition, a real textual answer and a real
// printed page are kept. Nothing is invented.
//
// Usage:
//   dart tool/build_history_budu5.dart                 -> tool/history_budu5.json
//   dart tool/build_history_budu5.dart --apply        -> also updates catalog.json
import 'dart:convert';
import 'dart:io';

const _base = 'https://budu5.com';

const _books = <Map<String, dynamic>>[
  {
    'id': 'history-8-medinsky-world',
    'viewId': 356,
    'subjectId': 'history',
    'grade': 8,
    'title': 'Всеобщая история. История Нового времени. XVIII — начало XIX в. 8 класс',
    'author': 'В. Р. Мединский, А. О. Чубарьян',
    'year': 2025,
    'publisher': 'Просвещение',
    'color': '#92400E',
    'sourceName': 'budu5-356',
  },
  {
    'id': 'history-9-medinsky-russia',
    'viewId': 358,
    'subjectId': 'history',
    'grade': 9,
    'title': 'История России. 1825–1914 гг. 9 класс',
    'author': 'В. Р. Мединский, А. Е. Торкунов',
    'year': 2025,
    'publisher': 'Просвещение',
    'color': '#92400E',
    'sourceName': 'budu5-358',
  },
  {
    'id': 'history-9-medinsky-world',
    'viewId': 359,
    'subjectId': 'history',
    'grade': 9,
    'title': 'Всеобщая история. История Нового времени. XIX — начало XX в. 9 класс',
    'author': 'В. Р. Мединский, А. О. Чубарьян',
    'year': 2025,
    'publisher': 'Просвещение',
    'color': '#92400E',
    'sourceName': 'budu5-359',
  },
];

Future<void> main(List<String> args) async {
  final apply = args.contains('--apply');
  final one = args.contains('--one');
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..idleTimeout = const Duration(seconds: 30)
    ..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  final catalogFile = File('assets/data/catalog.json');
  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final existingTextbooks =
      (catalog['textbooks'] as List).cast<Map<String, dynamic>>();
  final existingTasks = (catalog['tasks'] as List).cast<Map<String, dynamic>>();

  final result = <String, dynamic>{
    'textbooks': <Map<String, dynamic>>[],
    'tasks': <Map<String, dynamic>>[],
  };

  for (final book in (one ? _books.where((b) => b['viewId'] == 359) : _books)) {
    final textbookId = book['id'] as String;
    if (existingTextbooks.any((t) => t['id'] == textbookId) ||
        existingTasks.any((t) => t['textbookId'] == textbookId)) {
      stdout.writeln('skip already present: $textbookId');
      continue;
    }

    final index = await _index(client, book['viewId'] as int);
    final numbers = (one
        ? index.keys.where((n) => index[n] == '96904').toList()
        : index.keys.toList())
      ..sort();
    stdout.writeln('$textbookId: index ${index.length}, '
        'numbers ${numbers.isEmpty ? '-' : numbers.first}..'
        '${numbers.isEmpty ? '-' : numbers.last}');
    final pages = <int, Map<String, dynamic>>{};
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        final i = cursor++;
        if (i >= numbers.length) return;
        final n = numbers[i];
        try {
          pages[n] = await _task(client, index[n]!);
        } catch (e) {
          stderr.writeln('$textbookId $n: $e');
        }
      }
    }

    await Future.wait(List.generate(8, (_) => worker()));

    final tasks = <Map<String, dynamic>>[];
    for (final n in numbers) {
      final data = pages[n];
      if (data == null) continue;
      if (data['source'] != 'budu5') continue;
      final condition = '${data['condition']}';
      final answer = '${data['answer']}';
      final page = data['page'] as int;
      if (condition.trim().length < 20 || answer.trim().length < 8) continue;
      if (page <= 0) continue;
      final steps = (data['steps'] as List).cast<String>();
      if (steps.isEmpty) continue;
      final taskId = '$textbookId-$n';
      tasks.add({
        'id': taskId,
        'textbookId': textbookId,
        'number': '$n',
        'page': page,
        'condition': condition,
        'conditionSource': 'budu5',
        'solutionSource': data['source'],
        'solutions': [
          {
            'id': '$taskId-s1',
            'author': 'Команда ГДЗ',
            'rating': 4.8,
            'steps': steps,
            'answer': answer,
          }
        ],
        'source': 'budu5.com/gdztask',
      });
    }

    final textbook = Map<String, dynamic>.from(book)
      ..remove('viewId')
      ..remove('sourceName');
    (result['textbooks'] as List).add(textbook);
    (result['tasks'] as List).addAll(tasks);

    final pageList = tasks.map((t) => t['page'] as int).toList();
    stdout.writeln('$textbookId: ${tasks.length} tasks, '
        'pages ${pageList.isEmpty ? 0 : pageList.reduce(min)}..'
        '${pageList.isEmpty ? 0 : pageList.reduce(max)}, '
        'numbers ${tasks.isEmpty ? '-' : tasks.first['number']}..'
        '${tasks.isEmpty ? '-' : tasks.last['number']}');
  }

  client.close();

  final out = File('tool/history_budu5.json');
  out.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
  stdout.writeln('wrote ${out.path}');

  if (apply) {
    final resultTextbooks = (result['textbooks'] as List).cast<Map<String, dynamic>>();
    final resultTasks = (result['tasks'] as List).cast<Map<String, dynamic>>();
    if (resultTasks.isNotEmpty) {
      final insertAt = existingTextbooks.length;
      existingTextbooks.addAll(resultTextbooks);
      existingTasks.addAll(resultTasks);
      catalogFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(catalog)}\n',
      );
      stdout.writeln('catalog updated: +${resultTasks.length} tasks, '
          '+${resultTextbooks.length} textbooks (inserted after textbook $insertAt)');
    }
  }
}

int min(int a, int b) => a < b ? a : b;
int max(int a, int b) => a > b ? a : b;

String _clean(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty && line != 'Поделиться')
    .join('\n');

Future<Map<int, String>> _index(HttpClient client, int viewId) async {
  final body = await _get(client, '$_base/gdz/view/$viewId');
  final ids = <int, String>{};
  for (final m in RegExp(
          r'href="/gdztask/view/(\d+)"[^>]*>([\s\S]*?)</a>',
          dotAll: true)
      .allMatches(body)) {
    final label = _text(m.group(2)!).trim();
    final n = int.tryParse(label);
    if (n != null && !ids.containsKey(n)) ids[n] = m.group(1)!;
  }
  return ids;
}

Future<Map<String, dynamic>> _task(HttpClient client, String taskId) async {
  final body = await _get(client, '$_base/gdztask/view/$taskId');
  final meta = RegExp(r'Страница\s+(\d+)', caseSensitive: false)
      .firstMatch(body)
      ?.group(1);
  final marker = RegExp(r'\(стр\.\s*(\d+)\)').firstMatch(_text(body));
  final page = int.tryParse(meta ?? marker?.group(1) ?? '') ?? 0;

  final heads = <Map<String, dynamic>>[];
  for (final m in RegExp(r'panel-title"\s*>\s*(Вопрос|Подсказка|Ответ)\s*</h3>',
          caseSensitive: false)
      .allMatches(body)) {
    heads.add({'name': m.group(1)!.trim(), 'at': m.start, 'bodyAt': m.end});
  }
  String section(String name) => _text(_rawSection(body, heads, name));

  var condition = _clean(section('Вопрос'));
  condition = condition
      .replaceAll(RegExp(r'Выберите год учебника[\s\S]*?Все года[\s\S]*?'), '')
      .replaceAllMapped(
          RegExp(r'№\s*\d+\s*учебника\s*\d{4}-\d{4}\s*\(стр\.\s*\d+\):'), (_) => '')
      .trim();
  final answerRaw = _rawSection(body, heads, 'Ответ')
      .split('<div class="margin-bottom-15">')
      .first
      .split('web-share-button')
      .first
      .split('task-pagination-small')
      .first;
  final answer = _clean(_text(answerRaw));
  if (answer.isEmpty || answerRaw.contains('<img')) {
    return {'page': page, 'condition': condition, 'source': 'budu5-skip'};
  }

  final lines = answer
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  var finalAnswer = lines.last;
  final steps = List<String>.from(lines);
  if (steps.length > 1) steps.removeLast();
  if (steps.isEmpty) steps.add(answer);

  return {
    'page': page,
    'condition': condition,
    'steps': steps,
    'answer': finalAnswer,
    'source': 'budu5',
  };
}

String _rawSection(String body, List<Map<String, dynamic>> heads, String name) {
  final h = heads.where((x) => x['name'] == name).toList();
  if (h.isEmpty) return '';
  final marker = body.indexOf('panel-body', h.first['bodyAt'] as int);
  if (marker < 0) return '';
  var start = body.indexOf('>', marker);
  if (start < 0) return '';
  start++;
  final nextAt = heads
      .where((x) => (x['at'] as int) > start)
      .map((x) => x['at'] as int)
      .fold<int>(body.length, (a, b) => a < b ? a : b);
  final h3 = body.lastIndexOf('<h3', nextAt);
  final end = h3 > start ? h3 : nextAt;
  return body.substring(start, end);
}

Future<String> _get(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  if (response.statusCode != 200) {
    throw StateError('HTTP ${response.statusCode} $url');
  }
  return response.transform(utf8.decoder).join();
}

String _text(String html) {
  var s = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ')
      .replaceAllMapped(RegExp(r'<img[^>]*alt="([^"]*)"[^>]*>'),
          (m) => ' ${m.group(1)} ')
      .replaceAll(RegExp(r'<\s*(br|/p|/div|/li|/tr|/h[1-6])\s*/?\s*>',
          caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = <String, String>{
    '&nbsp;': ' ',
    '&mdash;': '—',
    '&ndash;': '–',
    '&laquo;': '«',
    '&raquo;': '»',
    '&quot;': '"',
    '&lt;': '<',
    '&gt;': '>',
    '&amp;': '&',
    '&times;': '×',
    '&bull;': '•',
    '&#8226;': '•',
  };
  entities.forEach((key, value) => s = s.replaceAll(key, value));
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)));
  return s.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
