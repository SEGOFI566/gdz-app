// Replaces the remaining placeholder tasks with real tasks from gdz.ru.
// These textbooks are not present on budu5.com, and gdz.ru does not expose
// printed page numbers, so `page` is set to 0 and the UI hides the page chip.
//
// Usage: dart tool/rebuild_gdz_pages.dart [--dry]
import 'dart:convert';
import 'dart:io';

const _gdz = 'https://gdz.ru';
const _books = <String, String>{
  'physics-8': '/class-8/fizika/peryshkin-2002/',
  'physics-9': '/class-9/fizika/peryshkin-gutnik/',
  'english-5': '/class-5/english/reshebnik-spotlight-5-angliyskiy-evans/',
  'english-7': '/class-7/english/reshebnik-angliyskiy-v-fokuse-vaulina-yu-e/',
  'english-9': '/class-9/english/reshebnik-spotlight-9-vaulina-yu-e/',
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
  for (final entry in _books.entries) {
    final textbookId = entry.key;
    final placeholders = tasks
        .where((t) =>
            t['textbookId'] == textbookId && t['conditionSource'] == null)
        .cast<Map<String, dynamic>>()
        .toList();
    if (placeholders.isEmpty) continue;
    final indexBody = await _get(client, _gdz + entry.value);
    final candidates = <String>[];
    for (final m in RegExp(
            r'href="(' + RegExp.escape(entry.value) + r'[^"]+)"')
        .allMatches(indexBody)) {
      final url = m.group(1)!;
      if (!candidates.contains(url)) candidates.add(url);
    }
    final usable = <String>[];
    final fetched = <String, Map<String, dynamic>>{};
    for (var i = 0; i < candidates.length && usable.length < placeholders.length; i++) {
      final url = candidates[i];
      final data = await _task(client, url, i + 1);
      fetched[url] = data;
      if ((data['condition'] as String).isNotEmpty) usable.add(url);
    }
    if (usable.length < placeholders.length) {
      stdout.writeln('!! $textbookId: only ${usable.length} usable tasks '
          '(scanned ${candidates.length} links)');
    }

    var done = 0;
    for (var i = 0; i < placeholders.length && i < usable.length; i++) {
      final data = fetched[usable[i]]!;
      final t = placeholders[i];
      t['number'] = data['number'];
      t['page'] = 0;
      t['condition'] = data['condition'];
      t['conditionSource'] = 'gdz.ru';
      t['solutionSource'] = 'gdz.ru';
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
      done++;
    }
    if (done > 0) {
      report.writeln('$textbookId: $done/${placeholders.length} tasks '
          'from gdz.ru, page unknown');
    }
  }
  client.close();
  stdout.writeln(report.toString());
  stdout.writeln('replaced: $total');
  if (!dry) {
    catalogFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(catalog)}\n');
    stdout.writeln('catalog written');
  }
}

Future<Map<String, dynamic>> _task(
    HttpClient client, String url, int fallback) async {
  final body = await _get(client, _gdz + url);
  final condMatch = RegExp(
          r'<(?:p|div) class="task__condition"[^>]*>([\s\S]*?)</(?:p|div)>')
      .firstMatch(body);
  final solMatch = RegExp(
          r'<div class="ai-card__content taskText__content"[^>]*>([\s\S]*?)</div>')
      .firstMatch(body);
  var condition = condMatch == null ? '' : _text(condMatch.group(1)!);
  var solution = solMatch == null ? '' : _text(solMatch.group(1)!);
  var label = url.split('/').where((s) => s.isNotEmpty).last.replaceAll('-', '.');
  label = label.replaceFirst(RegExp(r'\.s$'), '');
  if (condition.isEmpty) {
    return {
      'number': label.isEmpty ? '$fallback' : label,
      'condition': '',
      'steps': <String>[],
      'answer': '',
    };
  }
  final steps = solution
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (steps.isEmpty) steps.add('Подробный разбор — на сайте gdz.ru.');
  return {
    'number': label.isEmpty ? '$fallback' : label,
    'condition': condition,
    'steps': steps,
    'answer': solution.isEmpty ? 'См. разбор на gdz.ru.' : steps.last,
  };
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
      .replaceAll(RegExp(r'\*\*'), '')
      .replaceAll(
        RegExp(r'<\s*(br|/p|/div|/li|/h[1-6])\s*/?\s*>',
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
    '&shy;': '',
    '&#39;': "'",
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  return s
      .split('\n')
      .map((line) => line
          .replaceAll(RegExp(r'^\s*#{1,6}\s*'), '')
          .replaceAll(RegExp(r'^\s*\*\s+'), '• ')
          .replaceAll('*', '')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}
