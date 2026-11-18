// Builds real Barkhudarov 8 (2023-2026 edition) tasks and replaces the
// placeholder tasks in the catalog.
//
// Sources:
//   budu5.com      - conditions, printed page numbers, answers (primary)
//   gdz-raketa.ru  - same edition (2024): fills rare gaps in conditions/answers
//   tool/barkhudarov_overrides.json - hand-written solutions (optional)
//
// Usage:
//   dart tool/rebuild_barkhudarov.dart [catalog.json] [--dry]
//
// Produces:
//   tool/budu5_new.json          raw parsed exercises (audit)
//   tool/barkhudarov_report.txt  summary (numbers, pages, gaps, fallbacks)
import 'dart:convert';
import 'dart:io';

const _indexUrl = 'https://budu5.com/gdz/view/160';
const _base = 'https://budu5.com';
const _raketaBase =
    'https://gdz-raketa.ru/russkiy-yazyk/8-klass/uchebnik-barhudarov/upr-';
const _textbookId = 'russian-8-barkhudarov';
const _newEdition = '2023-2026';

Future<void> main(List<String> args) async {
  final catalogPath = args.isNotEmpty && !args.first.startsWith('--')
      ? args.first
      : 'assets/data/catalog.json';
  final dryRun = args.contains('--dry');

  final overrides = _readOverrides();
  final fromDump = args.contains('--from-dump');

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 25)
    ..idleTimeout = const Duration(seconds: 25)
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  final byNumber = <int, Map<String, dynamic>>{};
  final duplicates = <String>[];
  final failures = <String>[];
  final raketaFilled = <String>[];

  if (fromDump) {
    // Offline path: reuse the raw crawl, strip the site footer/share widget
    // and skip the network entirely.
    final dump =
        jsonDecode(File('tool/budu5_new.json').readAsStringSync()) as List;
    for (final raw in dump) {
      final item = Map<String, dynamic>.from(raw as Map);
      for (final key in ['condition', 'hint', 'answer']) {
        item[key] = _stripSiteJunk('${item[key] ?? ''}');
      }
      byNumber[item['number'] as int] = item;
    }
    stdout.writeln('== dump ==');
    stdout.writeln('exercises in dump: ${byNumber.length}');
  } else {
    stdout.writeln('== index ==');
    final indexHtml = await _get(client, _indexUrl);
    final links = <String>[];
    final seen = <String>{};
    for (final m in RegExp(r'/gdztask/view/(\d+)').allMatches(indexHtml)) {
      final id = m.group(1)!;
      if (seen.add(id)) links.add(id);
    }
    stdout.writeln('exercise pages: ${links.length}');
    if (links.isEmpty) {
      stderr.writeln('no links found');
      exit(2);
    }

    var cursor = 0;
    var done = 0;
    const workers = 5;

    Future<void> worker() async {
      while (true) {
        final i = cursor++;
        if (i >= links.length) return;
        final id = links[i];
        Map<String, dynamic>? task;
        try {
          task = _parseTask(await _get(client, '$_base/gdztask/view/$id'));
          if (task == null) {
            // A rare truncated response parses to nothing: retry once.
            task = _parseTask(await _get(client, '$_base/gdztask/view/$id'));
          }
        } catch (e) {
          failures.add('$id: $e');
        }
        if (task != null) {
          final number = task['number'] as int;
          final existing = byNumber[number];
          if (existing == null ||
              (existing['condition'] as String).length <
                  (task['condition'] as String).length) {
            if (existing != null) duplicates.add('$number (id $id richer)');
            byNumber[number] = task;
          } else {
            duplicates.add('$number (id $id skipped)');
          }
        }
        done++;
        if (done % 25 == 0) {
          stdout.writeln(
              'progress $done / ${links.length} (parsed ${byNumber.length})');
        }
      }
    }

    await Future.wait([for (var w = 0; w < workers; w++) worker()]);

    // Fill the rare gaps from the second source of the same edition.
    final numbers = byNumber.keys.toList()..sort();
    for (final number in numbers) {
      final task = byNumber[number]!;
      final needCondition = (task['condition'] as String).isEmpty;
      final needAnswer = (task['answer'] as String).isEmpty;
      if (!needCondition && !needAnswer) continue;
      final extra = await _raketa(client, number);
      if (needCondition && extra['condition']!.isNotEmpty) {
        task['condition'] = extra['condition'];
        task['conditionSource'] = 'gdz-raketa.ru';
        raketaFilled.add('$number (условие)');
      }
      if (needAnswer && extra['answer']!.isNotEmpty) {
        task['answer'] = extra['answer'];
        task['answerSource'] = 'gdz-raketa.ru';
        raketaFilled.add('$number (ответ)');
      }
    }
  }
  client.close(force: true);

  final numbers = byNumber.keys.toList()..sort();

  final dropped = <int>[];
  final usable = <int>[];
  for (final number in numbers) {
    if ((byNumber[number]!['condition'] as String).isEmpty) {
      dropped.add(number);
    } else {
      usable.add(number);
    }
  }
  final raw = [for (final n in usable) byNumber[n]!];
  File('tool/budu5_new.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(raw));
  stdout.writeln('parsed exercises: ${raw.length}');
  stdout.writeln('failures: ${failures.length}');
  if (failures.isNotEmpty) {
    File('tool/budu5_failures.txt').writeAsStringSync(failures.join('\n'));
  }

  if (raw.isEmpty) {
    stderr.writeln('nothing parsed');
    exit(3);
  }

  final catalogFile = File(catalogPath);
  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final existingTasks =
      (catalog['tasks'] as List).cast<Map<String, dynamic>>();
  final kept =
      existingTasks.where((t) => t['textbookId'] != _textbookId).toList();
  final removed = existingTasks.length - kept.length;

  final newTasks = <Map<String, dynamic>>[];
  final emptyAnswers = <int>[];
  for (final item in raw) {
    final number = item['number'] as int;
    final answer = (item['answer'] as String? ?? '').trim();
    final hint = (item['hint'] as String? ?? '').trim();
    if (answer.isEmpty) emptyAnswers.add(number);
    final override = overrides['$number'];
    newTasks.add({
      'id': '$_textbookId-$number',
      'textbookId': _textbookId,
      'number': '$number',
      'page': item['page'] as int,
      'condition': item['condition'] as String,
      'solutions': [
        {
          'id': '$_textbookId-$number-s1',
          'author': 'Команда ГДЗ',
          'rating': 4.8,
          'steps': override != null
              ? (override['steps'] as List).map((s) => '$s').toList()
              : _steps(hint, answer),
          'answer': override != null
              ? '${override['answer']}'
              : _shortAnswer(answer),
        }
      ],
    });
  }
  newTasks.sort((a, b) => int.parse(a['number'] as String)
      .compareTo(int.parse(b['number'] as String)));

  // Keep catalog tasks the dump does not contain (e.g. exercise 112 was added
  // by hand before the parser learned to keep pages with an empty "Вопрос").
  final dumped = byNumber.keys.toSet();
  final extras = existingTasks
      .where((t) => t['textbookId'] == _textbookId)
      .where((t) => !dumped.contains(int.tryParse('${t['number']}')))
      .toList();
  final allBark = [...newTasks, ...extras]
    ..sort((a, b) => int.parse(a['number'] as String)
        .compareTo(int.parse(b['number'] as String)));

  catalog['tasks'] = [...kept, ...allBark];

  final pages = allBark.map((t) => t['page'] as int).toList()..sort();
  final allNumbers = allBark.map((t) => int.parse('${t['number']}')).toList()
    ..sort();
  final gaps = <String>[];
  for (var i = 1; i < allNumbers.length; i++) {
    if (allNumbers[i] - allNumbers[i - 1] > 1) {
      gaps.add('${allNumbers[i - 1] + 1}..${allNumbers[i] - 1}');
    }
  }

  final report = StringBuffer()
    ..writeln('Бархударов, 8 класс, издание $_newEdition (budu5.com)')
    ..writeln('exercises in catalog: ${allBark.length}')
    ..writeln('number range: ${allNumbers.first}..${allNumbers.last}')
    ..writeln('page range: ${pages.first}..${pages.last}')
    ..writeln('gaps in numbering: ${gaps.isEmpty ? 'none' : gaps.join(', ')}')
    ..writeln('duplicates: ${duplicates.length}')
    ..writeln('kept from catalog (not in dump): '
        '${extras.isEmpty ? 'none' : extras.map((t) => t['number']).join(', ')}')
    ..writeln('dropped (no condition): '
        '${dropped.isEmpty ? 'none' : dropped.join(', ')}')
    ..writeln('filled from gdz-raketa: '
        '${raketaFilled.isEmpty ? 'none' : raketaFilled.join(', ')}')
    ..writeln('answers still empty: '
        '${emptyAnswers.isEmpty ? 'none' : emptyAnswers.join(', ')}')
    ..writeln('hand-written overrides: '
        '${overrides.keys.isEmpty ? 'none' : overrides.keys.join(', ')}')
    ..writeln('removed placeholder tasks: $removed')
    ..writeln('total tasks in catalog: ${catalog['tasks'].length}')
    ..writeln()
    ..writeln('number | page | condition chars | steps | answer chars');
  for (final t in allBark) {
    final solution = (t['solutions'] as List).first as Map<String, dynamic>;
    report.writeln('${t['number']} | ${t['page']} | '
        '${(t['condition'] as String).length} | '
        '${(solution['steps'] as List).length} | '
        '${(solution['answer'] as String).length}');
  }

  File('tool/barkhudarov_report.txt').writeAsStringSync(report.toString());
  stdout.write(report.toString().split('\n').take(12).join('\n'));
  stdout.writeln();

  if (dryRun) {
    stdout.writeln('dry run: catalog not written');
    return;
  }
  const encoder = JsonEncoder.withIndent('  ');
  catalogFile.writeAsStringSync('${encoder.convert(catalog)}\n');
  stdout.writeln('catalog written: ${catalogFile.path}');
}

Map<String, Map<String, dynamic>> _readOverrides() {
  final file = File('tool/barkhudarov_overrides.json');
  if (!file.existsSync()) return {};
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return data.map((key, value) => MapEntry(key, value as Map<String, dynamic>));
}

Future<String> _get(HttpClient client, String url) async {
  Object? lastError;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('Accept-Language', 'ru-RU,ru;q=0.9');
      final res = await req.close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw HttpException('status ${res.statusCode}', uri: Uri.parse(url));
      }
      final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      lastError = e;
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
  }
  throw lastError ?? HttpException('failed', uri: Uri.parse(url));
}

final _markerRe = RegExp(
  r'№\s*(\d+)\s+учебника\s+(\d{4})-(\d{4})\s*\(стр\.\s*(\d+)\):',
);
final _headingRe = RegExp(r'^\s*(Вопрос|Подсказка|Ответ)\s*$', multiLine: true);

Map<String, dynamic>? _parseTask(String html) {
  final bodyStart = html.indexOf('<body');
  final body = bodyStart >= 0 ? html.substring(bodyStart) : html;
  final text = _htmlToText(body);

  final heads = <Map<String, dynamic>>[];
  for (final m in _headingRe.allMatches(text)) {
    heads.add({'name': m.group(1), 'at': m.start, 'end': m.end});
  }
  if (heads.isEmpty) return null;

  // The book has a "Вопросы и задания для повторения" section whose items are
  // numbered 1..9 again; those pages must not overwrite the main exercises.
  // Detect it by the section title in the breadcrumb (before the first
  // "Вопрос" heading) — a real exercise may quote that title in its condition.
  final firstQuestion = heads
      .where((h) => h['name'] == 'Вопрос')
      .map((h) => h['at'] as int)
      .fold<int>(-1, (a, b) => a < 0 ? b : (a < b ? a : b));
  if (firstQuestion > 0 &&
      text.substring(0, firstQuestion).contains(
            'Вопросы и задания для повторения',
          )) {
    return null;
  }

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
  if (marks.isEmpty) return null;

  final number = marks.first['number'] as int;
  final current = marks
      .where((m) => m['number'] == number && m['edition'] == _newEdition)
      .toList();
  if (current.isEmpty) return null;

  String section(String name) {
    final head = heads.where((h) => h['name'] == name).toList();
    if (head.isEmpty) return '';
    final start = head.first['at'] as int;
    final nextHead = heads
        .where((h) => (h['at'] as int) > start)
        .map((h) => h['at'] as int)
        .fold<int>(text.length, (a, b) => a < b ? a : b);
    final marker = marks
        .where((m) =>
            (m['at'] as int) > start &&
            (m['at'] as int) < nextHead &&
            m['number'] == number &&
            m['edition'] == _newEdition)
        .toList();
    if (marker.isEmpty) return '';
    final from = marker.first['end'] as int;
    final next = marks
        .where((m) => (m['at'] as int) > from)
        .map((m) => m['at'] as int)
        .fold<int>(nextHead, (a, b) => a < b ? a : b);
    var value = text.substring(from, next);
    // Drop the site's share widget / navigation footer. A real condition can
    // contain "Поделиться с кем, чем" as an item to work with, so only cut
    // when the widget is a standalone line or is followed by the footer.
    final share = value.indexOf('Поделиться');
    if (share >= 0) {
      final lineStart = share == 0 || value[share - 1] == '\n';
      final tail = value.substring(share);
      if ((lineStart && !tail.contains(' с ')) ||
          tail.contains('Вернуться к содержанию')) {
        value = value.substring(0, share);
      }
    }
    final footer = value.indexOf('Вернуться к содержанию');
    if (footer >= 0) value = value.substring(0, footer);
    return _clean(value);
  }

  final condition = section('Вопрос');
  final hint = section('Подсказка');
  final answer = section('Ответ');
  if (condition.isEmpty && answer.isEmpty && hint.isEmpty) return null;

  return {
    'number': number,
    'page': current.first['page'] as int,
    'condition': condition,
    'conditionSource': 'budu5',
    'hint': hint,
    'answer': answer,
    'answerSource': 'budu5',
    'source': 'budu5.com/gdztask',
  };
}

Future<Map<String, String>> _raketa(HttpClient client, int number) async {
  const empty = {'condition': '', 'answer': ''};
  try {
    final text = _htmlToText(await _get(client, '$_raketaBase$number/'));
    final marker = 'Задание $number';
    final start = text.indexOf(marker);
    if (start < 0) return empty;
    final answerAt = text.indexOf('Ответ:', start);
    final endAt = text.indexOf('Конец страницы', start);
    final limit = endAt > start ? endAt : text.length;

    var condition = '';
    final conditionEnd =
        answerAt > start && answerAt < limit ? answerAt : limit;
    condition = _clean(text.substring(start + marker.length, conditionEnd))
        .replaceFirst(RegExp(r'^[.\s]+'), '');

    var answer = '';
    if (answerAt > start && answerAt < limit) {
      answer = _clean(text.substring(answerAt + 'Ответ:'.length, limit));
    }
    if (answer.length < 15) answer = '';
    return {'condition': condition, 'answer': answer};
  } catch (_) {
    return empty;
  }
}

String _htmlToText(String html) {
  var body = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ')
      .replaceAll(
        RegExp(r'<\s*(br|/p|/div|/li|/tr|/h[1-6]|/table|/ul|/ol)\s*/?\s*>',
            caseSensitive: false),
        '\n',
      );
  body = body.replaceAll(RegExp(r'<[^>]+>'), '');
  return _clean(body);
}

List<String> _steps(String hint, String answer) {
  final steps = <String>[];
  if (hint.isNotEmpty) {
    steps.add('Подсказка: ${_truncate(hint, 380)}');
  }
  final chunks = <String>[];
  for (final line in answer.split('\n')) {
    final text = line.trim();
    if (text.isEmpty) continue;
    if (text.length <= 320) {
      chunks.add(text);
    } else {
      chunks.addAll(_splitSentences(text));
    }
  }
  if (chunks.isEmpty) {
    steps.add('Открой учебник на указанной странице, выполни задание '
        'письменно и сверься с ответом.');
    return steps;
  }
  const limit = 20;
  if (chunks.length <= limit) {
    steps.addAll(chunks);
  } else {
    steps.addAll(chunks.take(limit - 1));
    steps.add(chunks.skip(limit - 1).join(' '));
  }
  return steps;
}

String _shortAnswer(String answer) {
  if (answer.isEmpty) return 'См. разбор в решении';
  final first = _splitSentences(answer).first;
  return _truncate(first, 220);
}

List<String> _splitSentences(String text) {
  final parts = <String>[];
  var buffer = StringBuffer();
  final chars = text.split('');
  for (var i = 0; i < chars.length; i++) {
    buffer.write(chars[i]);
    final ch = chars[i];
    final isEnd = ch == '.' || ch == '!' || ch == '?' || ch == ';';
    final next = i + 1 < chars.length ? chars[i + 1] : ' ';
    if (isEnd && (next == ' ' || next == '\n')) {
      final value = buffer.toString().trim();
      if (value.isNotEmpty) parts.add(value);
      buffer = StringBuffer();
    }
  }
  final tail = buffer.toString().trim();
  if (tail.isNotEmpty) parts.add(tail);
  if (parts.isEmpty) return [text.trim()];
  final merged = <String>[];
  for (final part in parts) {
    if (merged.isNotEmpty && merged.last.length < 40) {
      merged[merged.length - 1] = '${merged.last} $part';
    } else {
      merged.add(part);
    }
  }
  return merged;
}

String _truncate(String text, int max) {
  if (text.length <= max) return text;
  var cut = text.substring(0, max);
  final space = cut.lastIndexOf(' ');
  if (space > max * 0.6) cut = cut.substring(0, space);
  return '${cut.trimRight()}…';
}

/// Removes the site's share widget and navigation footer that the crawler can
/// pick up at the end of a section. A real task may contain "Поделиться с кем,
/// чем" as a word to work with, so only cut when it is a standalone line or is
/// followed by the footer.
String _stripSiteJunk(String value) {
  var text = value;
  final share = text.indexOf('Поделиться');
  if (share >= 0) {
    final lineStart = share == 0 || text[share - 1] == '\n';
    final tail = text.substring(share);
    if ((lineStart && !tail.contains(' с ')) ||
        tail.contains('Вернуться к содержанию')) {
      text = text.substring(0, share);
    }
  }
  final footer = text.indexOf('Вернуться к содержанию');
  if (footer >= 0) text = text.substring(0, footer);
  return text.trimRight();
}

String _clean(String text) {
  var t = text
      .replaceAll('\r', '\n')
      .replaceAll('\u00ad', '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&shy;', '')
      .replaceAll(RegExp(r'&#x25CF;'), '')
      .replaceAll(RegExp(r'&#\d+;'), ' ')
      .replaceAll(RegExp(r'&[a-zA-Z]+;'), ' ');
  t = t
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
  return t.trim();
}
