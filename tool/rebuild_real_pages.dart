// Replaces placeholder tasks (fabricated conditions/pages) with real tasks
// from budu5.com, including the printed page number taken from the source.
//
// Usage: dart tool/rebuild_real_pages.dart [--dry]
import 'dart:convert';
import 'dart:io';

const _base = 'https://budu5.com';
const _textbooks = <String, int>{
  'math-5': 61,
  'math-6': 43,
  'algebra-7': 296,
  'algebra-9': 342,
  'russian-5': 22,
  'russian-6': 37,
  'russian-8': 74,
  'russian-9': 236,
  'history-5': 256,
  'history-6': 324,
};

Future<void> main(List<String> args) async {
  final dry = args.contains('--dry');
  final catalogFile = File('assets/data/catalog.json');
  final catalog = jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final tasks = catalog['tasks'] as List<dynamic>;

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..idleTimeout = const Duration(seconds: 30)
    ..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  final report = StringBuffer();
  var total = 0;
  final indices = <String, Map<int, String>>{};

  for (final entry in _textbooks.entries) {
    final textbookId = entry.key;
    final index = await _index(client, entry.value);
    indices[textbookId] = index;
    final placeholders = tasks
        .where((t) =>
            t['textbookId'] == textbookId && t['conditionSource'] == null)
        .cast<Map<String, dynamic>>()
        .toList();
    if (placeholders.isEmpty) continue;

    final sorted = index.keys.toList()..sort();
    final wanted = sorted.take(placeholders.length).toList();
    if (wanted.length < placeholders.length) {
      stdout.writeln('!! $textbookId: need ${placeholders.length}, '
          'budu5 has ${sorted.length}');
    }
    final pages = <int, Map<String, dynamic>>{};
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        final i = cursor++;
        if (i >= wanted.length) return;
        final n = wanted[i];
        pages[n] = await _task(client, index[n]!);
      }
    }

    await Future.wait(List.generate(5, (_) => worker()));

    for (var i = 0; i < placeholders.length; i++) {
      final n = wanted[i];
      final data = pages[n]!;
      final t = placeholders[i];
      t['number'] = '$n';
      t['page'] = data['page'];
      t['condition'] = data['condition'];
      t['conditionSource'] = 'budu5';
      t['solutionSource'] = data['source'];
      t['solutions'] = [
        {
          'id': '${t['id']}-s1',
          'author': 'Команда ГДЗ',
          'rating': 4.8,
          'steps': data['steps'],
          'answer': data['answer'],
        }
      ];
      total++;
    }
    final ps = placeholders.map((t) => t['page'] as int).toList();
    report.writeln('$textbookId: ${placeholders.length} tasks, '
        'pages ${ps.reduce(min)}..${ps.reduce(max)}, '
        'numbers ${placeholders.first['number']}..${placeholders.last['number']}');
  }

  client.close();
  stdout.writeln(report.toString());
  stdout.writeln('replaced: $total');
  if (!dry) {
    catalogFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(catalog)}\n');
    stdout.writeln('catalog written');
  }
}

int min(int a, int b) => a < b ? a : b;
int max(int a, int b) => a > b ? a : b;

Future<Map<int, String>> _index(HttpClient client, int viewId) async {
  final body = await _get(client, '$_base/gdz/view/$viewId');
  final ids = <int, String>{};
  for (final m in RegExp(
          r'href="/gdztask/view/(\d+)"[^>]*>([\s\S]*?)</a>')
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
      .firstMatch(body)?.group(1);
  final marker = RegExp(r'\(стр\.\s*(\d+)\)').firstMatch(_text(body));
  final page = int.tryParse(meta ?? marker?.group(1) ?? '') ?? 0;

  final heads = <Map<String, dynamic>>[];
  for (final m in RegExp(r'panel-title"\s*>\s*(Вопрос|Подсказка|Ответ)\s*</h3>',
          caseSensitive: false)
      .allMatches(body)) {
    heads.add({'name': m.group(1)!.trim(), 'at': m.start, 'bodyAt': m.end});
  }
  String section(String name) => _text(_rawSection(body, heads, name));

  var condition = section('Вопрос');
  condition = condition
      .replaceAll(RegExp(r'Выберите год учебника[\s\S]*?Все года[\s\S]*?'),
          '')
      .replaceAllMapped(RegExp(r'№\s*\d+\s*учебника\s*\d{4}-\d{4}\s*\(стр\.\s*\d+\):'),
          (_) => '')
      .trim();
  final hint = section('Подсказка').trim();
  final answer = section('Ответ').trim();
  final answerRaw = _rawSection(body, heads, 'Ответ');
  final hasImage = answerRaw.contains('<img');

  final steps = <String>[];
  var source = 'budu5';
  var finalAnswer = '';
  if (answer.isNotEmpty && !hasImage) {
    steps.addAll(answer.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty));
    finalAnswer = steps.isEmpty ? '' : steps.last;
    if (steps.length > 1) steps.removeLast();
    if (steps.isEmpty) steps.add(answer);
  } else if (hint.isNotEmpty) {
    steps.addAll(hint.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty));
    source = 'budu5-hint';
    if (page > 0) steps.add('Подробный разбор — в учебнике на с. $page.');
  } else if (condition.isNotEmpty) {
    steps.add('Найдите это задание в учебнике на с. $page.');
    source = 'budu5-page';
  }
  if (steps.isEmpty) steps.add('Разбор отсутствует в источнике.');
  if (finalAnswer.isEmpty) finalAnswer = 'См. разбор в учебнике.';

  return {
    'page': page,
    'condition': condition,
    'steps': steps,
    'answer': finalAnswer,
    'source': source,
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
      .replaceAll(
        RegExp(r'<\s*(br|/p|/div|/li|/tr|/h[1-6])\s*/?\s*>',
            caseSensitive: false),
        '\n',
      )
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
    '&minus;': '−',
    '&plusmn;': '±',
    '&deg;': '°',
    '&shy;': '',
    '&#39;': "'",
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)));
  return s
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}
