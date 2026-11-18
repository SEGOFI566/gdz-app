// Builds an exercise -> page map from OCR'd page text files.
//
// Usage:
//   dart tool/parse_ocr2.dart <pagesDir> <outJson> [--report <outTxt>]
//
// Page files must be named so that lexicographic order == page order
// (e.g. p-000.txt, p-001.txt ...). The PDF page number is order + 1.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: parse_ocr2 <pagesDir> <outJson> [--report out.txt]');
    exit(1);
  }
  final dir = Directory(args[0]);
  final outPath = args.length > 1 ? args[1] : 'tool/barkhudarov_map.json';
  String? reportPath;
  final ri = args.indexOf('--report');
  if (ri >= 0 && ri + 1 < args.length) reportPath = args[ri + 1];

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final pages = <_Page>[];
  for (var i = 0; i < files.length; i++) {
    var text = files[i].readAsStringSync();
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    pages.add(_Page(
      index: i,
      pdfPage: i + 1,
      printed: _printedPage(text),
      text: text,
      lines: text.split('\n').map((l) => l.trimRight()).toList(),
    ));
  }

  // Collect candidate exercise starts across all pages, keeping global order.
  final candidates = <_Cand>[];
  for (final page in pages) {
    for (var li = 0; li < page.lines.length; li++) {
      final line = page.lines[li].trim();
      final m = _numRe.firstMatch(line);
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      if (n < 1 || n > 600) continue;
      final rest = line.substring(m.end).trim();
      candidate:
      {
        // Skip obvious page numbers and section markers.
        if (rest.isEmpty && page.lines.length > 1) {
          // A lone number line is usually a page number, unless it looks like
          // an exercise number followed by text on the next line.
          final next = li + 1 < page.lines.length ? page.lines[li + 1].trim() : '';
          if (next.isEmpty || RegExp(r'^\d+$').hasMatch(next)) continue;
        }
        candidates.add(_Cand(number: n, page: page, line: li, rest: rest));
        break candidate;
      }
    }
  }

  // Keep a monotonic increasing chain of numbers; allow small gaps because OCR
  // may miss numbers. Weight by closeness to the expected next number.
  final chain = <_Cand>[];
  var expected = 1;
  for (final c in candidates) {
    if (c.number < expected) continue;
    if (c.number > expected + 4) continue;
    chain.add(c);
    expected = c.number + 1;
  }

  // Build conditions: from a start line to the next start (possibly next page).
  final exercises = <Map<String, dynamic>>[];
  for (var k = 0; k < chain.length; k++) {
    final c = chain[k];
    final buf = StringBuffer();
    var page = c.page;
    var li = c.line;
    var guard = 0;
    while (guard++ < 40) {
      final isStart = page.index == c.page.index && li == c.line;
      if (!isStart) {
        final nextC = k + 1 < chain.length ? chain[k + 1] : null;
        if (nextC != null && page.index == nextC.page.index && li >= nextC.line) break;
        if (nextC == null && page.index > c.page.index + 1) break;
      }
      if (li >= page.lines.length) {
        // Move to the next page.
        if (page.index + 1 >= pages.length) break;
        final nextPage = pages[page.index + 1];
        // Stop if the next exercise starts on that page before any text.
        page = nextPage;
        li = 0;
        continue;
      }
      var line = page.lines[li].trim();
      if (isStart) line = c.rest;
      if (line.isNotEmpty) {
        if (!RegExp(r'^\d{1,3}$').hasMatch(line)) {
          buf.write(line);
          buf.write(' ');
        }
      }
      li++;
      if (buf.length > 1400) break;
    }

    var condition = buf
        .toString()
        .replaceAllMapped(
          RegExp(r'([а-яёА-ЯЁa-zA-Z])-\s+([а-яёА-ЯЁa-zA-Z])'),
          (m) => '${m.group(1)}${m.group(2)}',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (condition.length > 900) condition = '${condition.substring(0, 900)}…';

    exercises.add({
      'number': c.number,
      'pdfPage': c.page.pdfPage,
      'printedPage': c.page.printed,
      'condition': condition,
    });
  }

  final offsets = <int, int>{};
  for (final e in exercises) {
    final p = e['printedPage'] as int?;
    if (p == null) continue;
    final o = p - (e['pdfPage'] as int);
    offsets[o] = (offsets[o] ?? 0) + 1;
  }
  int? bestOffset;
  var bestCount = 0;
  offsets.forEach((o, c) {
    if (c > bestCount) {
      bestCount = c;
      bestOffset = o;
    }
  });

  final result = {
    'pageCount': pages.length,
    'offset': bestOffset,
    'offsetVotes': offsets,
    'exerciseCount': exercises.length,
    'pages': [
      for (final p in pages)
        {
          'pdfPage': p.pdfPage,
          'printedPage': p.printed,
          'chars': p.text.length,
        }
    ],
    'exercises': exercises,
  };

  File(outPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));

  stdout.writeln('pages: ${pages.length}');
  stdout.writeln('exercises: ${exercises.length}');
  stdout.writeln('offset votes: $offsets');
  if (exercises.isNotEmpty) {
    stdout.writeln('first: ${exercises.first}');
    stdout.writeln('last: ${exercises.last['number']} pdf=${exercises.last['pdfPage']} page=${exercises.last['printedPage']}');
  }

  if (reportPath != null) {
    final b = StringBuffer();
    for (final e in exercises) {
      b.writeln('${e['number']}\tpdf=${e['pdfPage']}\tpage=${e['printedPage']}');
      b.writeln('  ${e['condition']}');
    }
    File(reportPath).writeAsStringSync(b.toString());
  }
}

final _numRe = RegExp(r'^(\d{1,3})[.)]\s*(.*)$');

int? _printedPage(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;
  int? parse(String line) {
    final m = RegExp(r'^[•·\-–—\s]*(\d{1,3})[•·\-–—\s]*$').firstMatch(line);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    return (n > 0 && n < 320) ? n : null;
  }

  for (final line in lines.take(2)) {
    final n = parse(line);
    if (n != null) return n;
  }
  for (final line in lines.reversed.take(3)) {
    final n = parse(line);
    if (n != null) return n;
  }
  return null;
}

class _Page {
  _Page({
    required this.index,
    required this.pdfPage,
    required this.printed,
    required this.text,
    required this.lines,
  });
  final int index;
  final int pdfPage;
  final int? printed;
  final String text;
  final List<String> lines;
}

class _Cand {
  _Cand({
    required this.number,
    required this.page,
    required this.line,
    required this.rest,
  });
  final int number;
  final _Page page;
  final int line;
  final String rest;
}
