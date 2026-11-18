// Parses OCR text pages of the Barkhudarov textbook into an
// exercise -> page map with the exercise condition text.
//
// Usage: dart tool/parse_ocr.dart <pagesDir> <outJson>
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : 'tool/ocr_pages');
  final outPath = args.length > 1 ? args[1] : 'tool/barkhudarov_map.json';

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var expected = 1;
  final exercises = <Map<String, dynamic>>[];
  final pages = <Map<String, dynamic>>[];

  for (var i = 0; i < files.length; i++) {
    final pdfPage = i + 1;
    var text = files[i].readAsStringSync();
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final printed = _printedPage(text);
    final lines = text.split('\n');

    // Accept exercise numbers strictly in ascending order close to the
    // expected one, so that sub-items like "1." inside an exercise are skipped.
    final accepted = <int>[];
    for (var li = 0; li < lines.length; li++) {
      final m = RegExp(r'^\s*(\d{1,3})\s*[.)]\s*(.*)$').firstMatch(lines[li]);
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      final rest = m.group(2)!;
      if (n < expected || n > expected + 2) continue;
      if (rest.trim().isEmpty) continue;
      accepted.add(li);
      exercises.add({
        'number': n,
        'pdfPage': pdfPage,
        'printedPage': printed,
        'line': li,
      });
      expected = n + 1;
    }

    pages.add({
      'pdfPage': pdfPage,
      'printedPage': printed,
      'chars': text.length,
      'exercises': accepted.length,
    });

    // Attach condition text between this exercise and the next one.
    for (var k = 0; k < accepted.length; k++) {
      final start = accepted[k];
      final end = k + 1 < accepted.length ? accepted[k + 1] : lines.length;
      final buf = StringBuffer();
      for (var li = start; li < end; li++) {
        var line = lines[li].trim();
        if (li == start) {
          final m = RegExp(r'^\s*\d{1,3}\s*[.)]\s*(.*)$').firstMatch(line);
          if (m != null) line = m.group(1)!.trim();
        }
        if (line.isEmpty) continue;
        if (RegExp(r'^\d{1,3}$').hasMatch(line)) continue; // page number
        buf.write(line);
        buf.write(' ');
      }
      var condition = buf.toString().replaceAllMapped(
            RegExp(r'([а-яёА-ЯЁa-zA-Z])-\s+([а-яёА-ЯЁa-zA-Z])'),
            (m) => '${m.group(1)}${m.group(2)}',
          );
      condition = condition.replaceAll(RegExp(r'\s+'), ' ').trim();
      final ex = exercises.firstWhere(
        (e) => e['pdfPage'] == pdfPage && e['line'] == start,
      );
      ex['condition'] = condition.length > 700
          ? '${condition.substring(0, 700)}…'
          : condition;
    }
  }

  // Estimate printed page offset from the detected pairs.
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
    'pageCount': files.length,
    'offset': bestOffset,
    'offsetVotes': offsets,
    'exerciseCount': exercises.length,
    'first': exercises.isEmpty ? null : exercises.first,
    'last': exercises.isEmpty ? null : exercises.last,
    'exercises': exercises,
    'pages': pages,
  };

  File(outPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(result),
  );

  stdout.writeln('pages: ${files.length}');
  stdout.writeln('exercises: ${exercises.length}');
  stdout.writeln('offset votes: $offsets');
  if (exercises.isNotEmpty) {
    stdout.writeln('first: ${exercises.first['number']} '
        'pdf=${exercises.first['pdfPage']} '
        'page=${exercises.first['printedPage']}');
    stdout.writeln('last: ${exercises.last['number']} '
        'pdf=${exercises.last['pdfPage']} '
        'page=${exercises.last['printedPage']}');
  }
}

int? _printedPage(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;

  int? fromLine(String line) {
    final m = RegExp(r'^[•·\-–—\s]*(\d{1,3})[•·\-–—\s]*$').firstMatch(line);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    return n > 0 && n < 320 ? n : null;
  }

  // Page numbers usually sit in the footer or header, close to the edge.
  for (final line in lines.reversed.take(3)) {
    final n = fromLine(line);
    if (n != null) return n;
  }
  for (final line in lines.take(3)) {
    final n = fromLine(line);
    if (n != null) return n;
  }
  return null;
}
