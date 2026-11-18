// Crawls budu5.com exercise pages for the Barkhudarov 8 textbook and saves
// real exercise numbers, printed pages, conditions and answers.
//
// Usage: dart tool/crawl_budu5.dart <out.json> [maxPages]
import 'dart:convert';
import 'dart:io';

const indexUrl = 'https://budu5.com/gdz/view/160';
const base = 'https://budu5.com';

Future<void> main(List<String> args) async {
  final outPath = args.isNotEmpty ? args[0] : 'tool/budu5_new.json';
  final maxPages = args.length > 1 ? int.parse(args[1]) : 0;
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) gdz-catalog-builder';

  final indexHtml = await _get(client, indexUrl);
  final marker = indexHtml.indexOf('id="chapter-gdz-160"');
  final head = marker > 0 ? indexHtml.substring(0, marker) : indexHtml;

  final linkRe = RegExp(r'<a[^>]+href="(/gdztask/view/(\d+))"[^>]*>([\s\S]*?)</a>');
  final links = <Map<String, String>>[];
  final seen = <String>{};
  for (final m in linkRe.allMatches(head)) {
    final href = m.group(1)!;
    if (!seen.add(href)) continue;
    final label = m.group(3)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    links.add({'href': href, 'label': label});
  }
  stdout.writeln('links: ${links.length}');
  if (links.isEmpty) exit(2);
  final take = maxPages > 0 && maxPages < links.length ? maxPages : links.length;

  final results = <Map<String, dynamic>>[];
  const concurrency = 6;
  var cursor = 0;
  var done = 0;

  Future<void> worker() async {
    while (true) {
      final i = cursor++;
      if (i >= take) return;
      final link = links[i];
      try {
        final html = await _get(client, base + link['href']!);
        final parsed = _parseTask(html, link['label']!);
        if (parsed != null) results.add(parsed);
      } catch (e) {
        stderr.writeln('fail ${link['href']}: $e');
      }
      done++;
      if (done % 20 == 0) stdout.writeln('done $done / $take');
    }
  }

  await Future.wait([for (var w = 0; w < concurrency; w++) worker()]);

  results.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
  File(outPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(results),
  );
  stdout.writeln('saved ${results.length} -> $outPath');
  client.close(force: true);
}

Future<String> _get(HttpClient client, String url) async {
  final req = await client.getUrl(Uri.parse(url));
  final res = await req.close();
  if (res.statusCode != 200) {
    throw HttpException('status ${res.statusCode}');
  }
  final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
  return utf8.decode(bytes, allowMalformed: true);
}

final _markerRe = RegExp(r'№\s*(\d+)\s+учебника\s+(\d{4})-(\d{4})\s*\(стр\.\s*(\d+)\):');

Map<String, dynamic>? _parseTask(String html, String label) {
  final bodyStart = html.indexOf('<body');
  var body = bodyStart > 0 ? html.substring(bodyStart) : html;
  body = body
      .replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ');
  var text = body.replaceAll(RegExp(r'<[^>]+>'), '\n');
  text = _clean(text);

  final numMatch = RegExp(r'Упражнение\s+(\d+)').firstMatch(text) ??
      RegExp(r'№\s*(\d+)\s+учебника').firstMatch(text);
  final number = int.tryParse(numMatch?.group(1) ?? label);
  if (number == null) return null;

  final pageMatch = RegExp(r'Страница\s+(\d+)').firstMatch(text);
  final page = int.tryParse(pageMatch?.group(1) ?? '');

  // All edition markers, in order: condition (new), condition (old),
  // answer (new), answer (old) and possibly hints.
  final marks = <Map<String, dynamic>>[];
  for (final m in _markerRe.allMatches(text)) {
    marks.add({
      'at': m.start,
      'end': m.end,
      'number': int.parse(m.group(1)!),
      'edition': '${m.group(2)}-${m.group(3)}',
      'page': int.parse(m.group(4)!),
    });
  }
  final mine = marks.where((m) => m['number'] == number).toList();
  if (mine.isEmpty) return null;

  String slice(Map<String, dynamic> from) {
    final next = marks.firstWhere(
      (m) => (m['at'] as int) > (from['at'] as int),
      orElse: () => const {},
    );
    var end = next.isEmpty ? text.length : next['at'] as int;
    var value = text.substring(from['end'] as int, end);
    final cut = value.indexOf('Поделиться');
    if (cut >= 0) value = value.substring(0, cut);
    return _clean(value);
  }

  final newMarks = mine.where((m) => m['edition'] == '2023-2026').toList();
  final condition = newMarks.isEmpty ? '' : slice(newMarks.first);
  final answer = newMarks.length > 1 ? slice(newMarks[1]) : '';
  final printedPage = newMarks.isNotEmpty ? newMarks.first['page'] as int : page;

  if (condition.isEmpty) return null;
  return {
    'number': number,
    'page': printedPage,
    'condition': condition,
    'answer': answer,
    'source': 'budu5',
  };
}

String _clean(String text) {
  var t = text
      .replaceAll('\r', '\n')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&mdash;', '—')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('\u00ad', '')
      .replaceAll(RegExp(r'&#x25CF;'), '')
      .replaceAll(RegExp(r'&#\d+;'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n')
      .trim();
  return t;
}
