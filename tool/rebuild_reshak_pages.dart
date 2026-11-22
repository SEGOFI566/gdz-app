// Replaces the remaining placeholder tasks with real tasks from reshak.ru.
// gdz.ru only has scans for these books, while reshak.ru has text conditions
// and solutions. Neither source exposes printed page numbers, so `page` is 0
// and the UI hides the page chip.
//
// Usage: dart tool/rebuild_reshak_pages.dart [--dry]
import 'dart:convert';
import 'dart:io';

const _reshak = 'https://reshak.ru';
const _books = <String, String>{
  'chemistry-8': '/reshebniki/ximiya/8/gabrielyan/index.html',
  'chemistry-9': '/reshebniki/ximiya/9/gabrielyan_new/index.html',
  'biology-5': '/reshebniki/biologia/5/pasechnik/index.html',
  'biology-7': '/reshebniki/biologia/7/latushin/index.html',
  'informatics-8': '/reshebniki/informatika/8/bosova_uchebnik/index.html',
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

    final indexBody = await _get(client, _reshak + entry.value);
    final candidates = <String>[];
    for (final m in RegExp(r'href="(/otvet/[^"]+\.php\?[^"]+)"')
        .allMatches(indexBody)) {
      final url = m.group(1)!.replaceAll('&amp;', '&');
      if (!candidates.contains(url)) candidates.add(url);
    }
    if (candidates.isEmpty) {
      stdout.writeln('!! $textbookId: no answer links in index');
      continue;
    }

    final usable = <String>[];
    final fetched = <String, Map<String, dynamic>>{};
    for (var i = 0;
        i < candidates.length && usable.length < placeholders.length;
        i++) {
      final url = candidates[i];
      try {
        final data = await _task(client, url);
        fetched[url] = data;
        if (data['condition'].isNotEmpty) usable.add(url);
      } on StateError catch (e) {
        stdout.writeln('   skip $url: ${e.message}');
      }
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
      t['conditionSource'] = 'reshak.ru';
      t['solutionSource'] = 'reshak.ru';
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
          'from reshak.ru, page unknown');
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

Future<Map<String, dynamic>> _task(HttpClient client, String url) async {
  final body = await _get(client, _reshak + url);
  final titleMatch = RegExp(r'<title>([\s\S]*?)</title>', caseSensitive: false)
      .firstMatch(body);
  final titleText = titleMatch == null ? '' : _text(titleMatch.group(1)!);

  final blockMatch = RegExp(
          r'<div class="text_zad">([\s\S]*?)</div>\s*</div>',
          caseSensitive: false)
      .firstMatch(body);
  if (blockMatch == null) throw StateError('no .text_zad');
  var block = blockMatch.group(1)!
      .replaceAll(RegExp(r'<noindex>[\s\S]*?</noindex>', caseSensitive: false), ' ');
  final parts = <String>[];
  for (final m in RegExp(r'<div[^>]*>([\s\S]*?)</div>', caseSensitive: false)
      .allMatches(block)) {
    final text = _text(m.group(1)!);
    if (text.isEmpty) continue;
    if (text.contains('Рассмотрим вариант решения задания') ||
        text.contains('Текст задания приводится')) {
      continue;
    }
    parts.add(text);
  }
  if (parts.isEmpty) throw StateError('empty .text_zad');
  final condition = parts.first;
  final steps = parts.skip(1).toList();
  if (steps.isEmpty) throw StateError('no solution steps');

  final para = RegExp(r'Параграф\s*([\d.]+)', caseSensitive: false)
      .firstMatch(titleText)
      ?.group(1);
  final zad = RegExp(r'Задание\s*(\d+)', caseSensitive: false)
      .firstMatch(titleText)
      ?.group(1);
  final vop = RegExp(r'Вопрос\s*(\d+)', caseSensitive: false)
      .firstMatch(titleText)
      ?.group(1);
  final buffer = StringBuffer();
  if (para != null) buffer.write('§$para');
  if (zad != null) {
    if (buffer.isNotEmpty) buffer.write(' · ');
    buffer.write('задание $zad');
  } else if (vop != null) {
    if (buffer.isNotEmpty) buffer.write(' · ');
    buffer.write('вопрос $vop');
  }
  final number = buffer.isEmpty ? titleText : buffer.toString();

  return {
    'number': number,
    'condition': condition,
    'steps': steps,
    'answer': steps.last,
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
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll('**', '')
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
    '&shy;': '',
    '&#39;': "'",
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  s = s.replaceAllMapped(
      RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
  return s
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}
