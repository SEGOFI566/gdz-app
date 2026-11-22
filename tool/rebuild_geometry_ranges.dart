// Builds real Geometry 7/8/9 (Atanasyan 7-9, 2023-2026 edition) tasks and
// replaces the placeholder tasks in the catalog.
//
// Sources:
//   budu5.com   - conditions, printed pages, hints (2023-2026 numbering)
//   gdz.ru      - AI step-by-step solutions for the same numbering
//   reshak.ru   - solutions for the tasks gdz.ru does not cover
//
// Usage:
//   dart tool/rebuild_geometry_ranges.dart
//     --textbook=geometry-7 --first=1 --last=461
//     [--dry] [--offline]
//
// Produces:
//   tool/geometryN_raw.json      raw parsed pages (audit / offline re-runs)
//   tool/geometryN_report.txt    summary (numbers, pages, sources, gaps)
import 'dart:convert';
import 'dart:io';

const _budu5IndexUrl = 'https://budu5.com/gdz/view/63';
const _budu5Base = 'https://budu5.com';
const _gdzIndexUrl = 'https://gdz.ru/class-7/geometria/atanasyan-7-9/';
const _gdzBase = 'https://gdz.ru';
const _reshakUrl = 'https://reshak.ru/otvet/otvet11.php?otvet1=';
const _edition = '2023-2026';
String _textbookId = 'geometry-8';
int _first = 462;
int _last = 929;

Future<void> main(List<String> args) async {
  final catalogPath = args.isNotEmpty && !args.first.startsWith('--')
      ? args.first
      : 'assets/data/catalog.json';
  final dryRun = args.contains('--dry');
  final offline = args.contains('--offline');
  final noReshak = args.contains('--no-reshak');
  for (final arg in args) {
    if (arg.startsWith('--textbook=')) {
      _textbookId = arg.substring('--textbook='.length);
    } else if (arg.startsWith('--first=')) {
      _first = int.parse(arg.substring('--first='.length));
    } else if (arg.startsWith('--last=')) {
      _last = int.parse(arg.substring('--last='.length));
    }
  }
  final suffix = _textbookId.replaceAll('geometry-', '');
  stdout.writeln('== $_textbookId: $_first..$_last ==');

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..idleTimeout = const Duration(seconds: 30)
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  final rawFile = File('tool/geometry${suffix}_raw.json');
  final raw = <String, dynamic>{};
  if (offline && rawFile.existsSync()) {
    raw.addAll(jsonDecode(rawFile.readAsStringSync()) as Map<String, dynamic>);
    stdout.writeln('== offline ==');
    stdout.writeln('raw cache: ${rawFile.path}');
  } else {
    raw['budu5'] = await _crawlBudu5(client);
    raw['gdz'] = await _crawlGdz(client, raw['budu5'] as Map<String, dynamic>);
    if (!noReshak) {
      raw['reshak'] =
          await _crawlReshak(client, raw['budu5'] as Map<String, dynamic>);
    } else {
      raw['reshak'] = <String, dynamic>{};
    }
    rawFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(raw));
    stdout.writeln('raw cache written: ${rawFile.path}');
  }
  client.close(force: true);

  final budu5 = (raw['budu5'] as Map).cast<String, dynamic>();
  final gdz = (raw['gdz'] as Map).cast<String, dynamic>();
  final reshak = (raw['reshak'] as Map).cast<String, dynamic>();

  final catalogFile = File(catalogPath);
  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final existingTasks =
      (catalog['tasks'] as List).cast<Map<String, dynamic>>();
  final kept =
      existingTasks.where((t) => t['textbookId'] != _textbookId).toList();
  final removed = existingTasks.length - kept.length;

  final newTasks = <Map<String, dynamic>>[];
  final missing = <int>[];
  final emptyConditions = <int>[];
  final sources = <String, int>{'gdz.ru': 0, 'reshak.ru': 0, 'hint': 0};
  final noSolution = <int>[];
  final reshakUsed = <int>[];
  final mismatched = <String>[];
  final pages = <int>[];

  for (var n = _first; n <= _last; n++) {
    final b = (budu5['$n'] as Map?)?.cast<String, dynamic>();
    if (b == null) {
      missing.add(n);
      continue;
    }
    final page = (b['page'] as num?)?.toInt() ?? 0;
    if (page > 0) pages.add(page);

    var condition = (b['condition'] as String? ?? '').trim();
    var conditionSource = 'budu5';
    final g = (gdz['$n'] as Map?)?.cast<String, dynamic>();
    final gCond = (g?['condition'] as String? ?? '').trim();
    if (gCond.isNotEmpty && _similar(gCond, condition) >= 0.6) {
      final tidy = _tidyCondition(gCond, n);
      if (tidy.length >= 12) {
        condition = tidy;
        conditionSource = 'gdz.ru';
      }
    }
    if (condition.isEmpty) {
      emptyConditions.add(n);
      continue;
    }

    final hint = (b['hint'] as String? ?? '').trim();

    Map<String, dynamic>? solution;
    var solutionSource = '';
    final gAi = (g?['ai'] as String? ?? '').trim();
    // gdz.ru mixes editions: its condition block is only present for the
    // tasks whose numbering matches the 2023-2026 book. Without a condition
    // there is no way to prove the solution belongs to this exercise, so the
    // AI text is used only when both texts clearly describe the same task.
    if (gAi.length >= 40 &&
        gCond.isNotEmpty &&
        _similar(gCond, condition) >= 0.55) {
      final parsed = _solutionFromText(gAi, page);
      if (parsed['steps']!.length >= 2) {
        solution = parsed;
        solutionSource = 'gdz.ru';
        sources['gdz.ru'] = sources['gdz.ru']! + 1;
      }
    }
    if (solution == null) {
      final r = (reshak['$n'] as Map?)?.cast<String, dynamic>();
      // Score the real solution only: raw pages also contain other editions
      // of the task, which would otherwise produce false matches.
      final rText = _trimSolutionBoilerplate(
          (r?['solution'] as String? ?? '').trim());
      final rTask = _trimSolutionBoilerplate(
          (r?['task'] as String? ?? '').trim());
      final score = _reshakScore(rText, rTask, condition);
      final hits = _keywordHits(condition, '$rTask\n$rText');
      if (rText.length >= 40 && score >= 0.34 && hits >= 2) {
        final parsed = _solutionFromText(rText, page);
        if (parsed['steps']!.length >= 2) {
          solution = parsed;
          solutionSource = 'reshak.ru';
          sources['reshak.ru'] = sources['reshak.ru']! + 1;
          reshakUsed.add(n);
        } else {
          mismatched.add('$n (reshak: короткое решение, score $score)');
        }
      } else if (rText.isNotEmpty) {
        mismatched.add('$n (reshak: score ${score.toStringAsFixed(2)}, '
            'ключевых слов $hits)');
      }
    }
    if (solution == null) {
      solution = _fallbackSolution(hint, page);
      solutionSource = 'hint';
      sources['hint'] = sources['hint']! + 1;
      noSolution.add(n);
    }

    newTasks.add({
      'id': '$_textbookId-$n',
      'textbookId': _textbookId,
      'number': '$n',
      'page': page,
      'condition': condition,
      'conditionSource': conditionSource,
      'solutionSource': solutionSource,
      'solutions': [
        {
          'id': '$_textbookId-$n-s1',
          'author': 'Команда ГДЗ',
          'rating': 4.8,
          'steps': solution['steps'],
          'answer': solution['answer'],
        }
      ],
    });
  }

  newTasks.sort((a, b) => int.parse(a['number'] as String)
      .compareTo(int.parse(b['number'] as String)));
  catalog['tasks'] = [...kept, ...newTasks];

  final numbers = newTasks.map((t) => int.parse(t['number'] as String)).toList()
    ..sort();
  final gaps = <String>[];
  for (var i = 1; i < numbers.length; i++) {
    if (numbers[i] - numbers[i - 1] > 1) {
      gaps.add('${numbers[i - 1] + 1}..${numbers[i] - 1}');
    }
  }
  pages.sort();

  final report = StringBuffer()
    ..writeln('Геометрия, $suffix класс, издание $_edition (Атанасян 7-9)')
    ..writeln('tasks in catalog: ${newTasks.length}')
    ..writeln('number range: ${numbers.isEmpty ? '-' : '${numbers.first}..${numbers.last}'}')
    ..writeln('page range: ${pages.isEmpty ? '-' : '${pages.first}..${pages.last}'}')
    ..writeln('gaps in numbering: ${gaps.isEmpty ? 'none' : gaps.join(', ')}')
    ..writeln('missing on budu5: ${missing.isEmpty ? 'none' : missing.join(', ')}')
    ..writeln('empty conditions: '
        '${emptyConditions.isEmpty ? 'none' : emptyConditions.join(', ')}')
    ..writeln('solutions: gdz.ru ${sources['gdz.ru']}, '
        'reshak.ru ${sources['reshak.ru']}, '
        'hint fallback ${sources['hint']}')
    ..writeln('no full solution: '
        '${noSolution.isEmpty ? 'none' : _ranges(noSolution)}')
    ..writeln('reshak accepted: '
        '${reshakUsed.isEmpty ? 'none' : _ranges(reshakUsed)}')
    ..writeln('reshak rejected: ${mismatched.isEmpty ? 'none' : mismatched.length}')
    ..writeln('removed placeholder tasks: $removed')
    ..writeln('total tasks in catalog: ${catalog['tasks'].length}')
    ..writeln()
    ..writeln('number | page | condition | steps | answer | source');

  for (final t in newTasks) {
    final s = (t['solutions'] as List).first as Map<String, dynamic>;
    final source = '${t['conditionSource']}/${t['solutionSource']}';
    report.writeln('${t['number']} | ${t['page']} | '
        '${(t['condition'] as String).length} | '
        '${(s['steps'] as List).length} | '
        '${(s['answer'] as String).length} | $source');
  }
  if (mismatched.isNotEmpty) {
    report
      ..writeln()
      ..writeln('reshak rejected details:')
      ..writeln(mismatched.join('\n'));
  }

  File('tool/geometry${suffix}_report.txt').writeAsStringSync(report.toString());
  stdout.write(report.toString().split('\n').take(14).join('\n'));
  stdout.writeln();

  if (dryRun) {
    stdout.writeln('dry run: catalog not written');
    return;
  }
  const encoder = JsonEncoder.withIndent('  ');
  catalogFile.writeAsStringSync('${encoder.convert(catalog)}\n');
  stdout.writeln('catalog written: ${catalogFile.path}');
}

// ---------------------------------------------------------------------------
// Crawling
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>> _crawlBudu5(HttpClient client) async {
  stdout.writeln('== budu5 index ==');
  final index = await _get(client, _budu5IndexUrl);
  final ids = <int, String>{};
  for (final m in RegExp(r'href="/gdztask/view/(\d+)"[^>]*>([\s\S]*?)</a>')
      .allMatches(index)) {
    final label = _htmlToText(m.group(2)!).trim();
    final n = int.tryParse(label);
    if (n != null && !ids.containsKey(n)) ids[n] = m.group(1)!;
  }
  stdout.writeln('indexed exercises: ${ids.length}');

  final result = <String, dynamic>{};
  var cursor = 0;
  var done = 0;
  const workers = 5;

  Future<void> worker() async {
    while (true) {
      final i = cursor++;
      if (i >= _last - _first + 1) return;
      final n = _first + i;
      final id = ids[n];
      if (id == null) continue;
      try {
        final html = await _get(client, '$_budu5Base/gdztask/view/$id');
        final parsed = _parseBudu5(html, n);
        if (parsed != null) result['$n'] = parsed;
      } catch (e) {
        stderr.writeln('budu5 $n: $e');
      }
      done++;
      if (done % 25 == 0) {
        stdout.writeln('budu5 progress $done / ${_last - _first + 1} '
            '(parsed ${result.length})');
      }
    }
  }

  await Future.wait([for (var w = 0; w < workers; w++) worker()]);
  stdout.writeln('budu5 parsed: ${result.length}');
  return result;
}

Future<Map<String, dynamic>> _crawlGdz(
    HttpClient client, Map<String, dynamic> budu5) async {
  stdout.writeln('== gdz.ru index ==');
  final index = await _get(client, _gdzIndexUrl);
  final parts = <int, String>{};
  for (final m in RegExp(
          r'href="([^"]*?atanasyan-7-9/(\d+)-chapter-(\d+)/)"')
      .allMatches(index)) {
    final n = int.parse(m.group(3)!);
    parts.putIfAbsent(n, () => m.group(2)!);
  }
  stdout.writeln('gdz.ru indexed exercises: ${parts.length}');

  final result = <String, dynamic>{};
  var cursor = 0;
  var done = 0;
  const workers = 4;

  Future<void> worker() async {
    while (true) {
      final i = cursor++;
      if (i >= _last - _first + 1) return;
      final n = _first + i;
      final part = parts[n];
      if (part == null) continue;
      try {
        final html =
            await _get(client, '$_gdzBase/class-7/geometria/atanasyan-7-9/'
                '$part-chapter-$n/');
        final parsed = _parseGdz(html);
        if (parsed != null) result['$n'] = parsed;
      } catch (e) {
        stderr.writeln('gdz $n: $e');
      }
      done++;
      if (done % 25 == 0) {
        stdout.writeln('gdz progress $done / ${parts.length} '
            '(parsed ${result.length})');
      }
    }
  }

  await Future.wait([for (var w = 0; w < workers; w++) worker()]);
  stdout.writeln('gdz parsed: ${result.length}');
  return result;
}

Future<Map<String, dynamic>> _crawlReshak(
    HttpClient client, Map<String, dynamic> budu5) async {
  stdout.writeln('== reshak.ru ==');
  final result = <String, dynamic>{};
  var cursor = 0;
  var done = 0;
  const workers = 4;

  Future<void> worker() async {
    while (true) {
      final i = cursor++;
      if (i >= _last - _first + 1) return;
      final n = _first + i;
      try {
        final html = await _get(client, '$_reshakUrl$n');
        final parsed = _parseReshak(html);
        if (parsed != null) result['$n'] = parsed;
      } catch (e) {
        stderr.writeln('reshak $n: $e');
      }
      done++;
      if (done % 50 == 0) {
        stdout.writeln('reshak progress $done / ${_last - _first + 1} '
            '(parsed ${result.length})');
      }
    }
  }

  await Future.wait([for (var w = 0; w < workers; w++) worker()]);
  stdout.writeln('reshak parsed: ${result.length}');
  return result;
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
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
  }
  throw lastError ?? HttpException('failed', uri: Uri.parse(url));
}

// ---------------------------------------------------------------------------
// Parsers
// ---------------------------------------------------------------------------

final _budu5MarkerRe = RegExp(
  r'№\s*(\d+)\s+учебника\s+(\d{4})-(\d{4})\s*\(стр\.\s*(\d+)\):',
);
final _headingRe = RegExp(r'^\s*(Вопрос|Подсказка|Ответ)\s*$', multiLine: true);

Map<String, dynamic>? _parseBudu5(String html, int expected) {
  final bodyStart = html.indexOf('<body');
  final body = bodyStart >= 0 ? html.substring(bodyStart) : html;
  // Markers are sometimes split over two lines ("№423 учебника 2023-2026"
  // then "(стр. 116):"); glue them back before matching.
  final text = _htmlToText(body).replaceAllMapped(
    RegExp(r'(№\s*\d+\s+учебника\s+\d{4}-\d{4})\s*\n\s*(?=\()'),
    (m) => '${m[1]} ',
  );

  final heads = <Map<String, dynamic>>[];
  for (final m in _headingRe.allMatches(text)) {
    heads.add({'name': m.group(1), 'at': m.start, 'end': m.end});
  }
  if (heads.isEmpty) return null;

  final marks = <Map<String, dynamic>>[];
  for (final m in _budu5MarkerRe.allMatches(text)) {
    marks.add({
      'at': m.start,
      'end': m.end,
      'number': int.parse(m.group(1)!),
      'edition': '${m.group(2)}-${m.group(3)}',
      'page': int.parse(m.group(4)!),
    });
  }
  if (marks.isEmpty) return null;

  final current = marks
      .where((m) => m['number'] == expected && m['edition'] == _edition)
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
            m['number'] == expected &&
            m['edition'] == _edition)
        .toList();
    if (marker.isEmpty) return '';
    final from = marker.first['end'] as int;
    final next = marks
        .where((m) => (m['at'] as int) > from)
        .map((m) => m['at'] as int)
        .fold<int>(nextHead, (a, b) => a < b ? a : b);
    return _stripSiteJunk(text.substring(from, next));
  }

  final condition = section('Вопрос');
  final hint = section('Подсказка');
  final answer = section('Ответ');
  if (condition.isEmpty && hint.isEmpty && answer.isEmpty) return null;

  return {
    'number': expected,
    'page': current.first['page'] as int,
    'condition': condition,
    'hint': hint,
    'answer': answer,
    'source': 'budu5.com/gdztask',
  };
}

Map<String, dynamic>? _parseGdz(String html) {
  final cond = RegExp(r'<p class="task__condition">([\s\S]*?)</p>')
          .firstMatch(html)?[1] ??
      '';
  final aiMatch =
      RegExp(r'<div class="ai-card__content taskText__content">([\s\S]*?)</div>')
          .firstMatch(html);
  final ai = aiMatch?[1] ?? '';
  if (cond.trim().isEmpty && ai.trim().isEmpty) return null;
  return {
    'condition': _inline(cond),
    'ai': _inline(ai),
  };
}

Map<String, dynamic>? _parseReshak(String html) {
  final start = html.indexOf('ai-analysis__answer is-active');
  if (start < 0) return null;
  final open = html.indexOf('>', start);
  if (open < 0) return null;
  // The answer block nests several divs, so cut at the next structural
  // marker instead of the first closing tag.
  var end = html.length;
  for (final stop in const [
    'ai-analysis__sequence-item',
    'ai-analysis__nav',
    'Показать полностью',
    'Оцени решение',
  ]) {
    final at = html.indexOf(stop, open);
    if (at > open && at < end) end = at;
  }
  final solution = _inline(html.substring(open + 1, end));

  // The restatement that follows the "▸" marker is a short paraphrase of the
  // task; it is only used for source matching.
  final marker = html.indexOf('ai-analysis__task-marker', open);
  var task = '';
  if (marker >= 0) {
    final markerEnd = html.indexOf('>', marker);
    if (markerEnd >= 0) {
      final label = html.indexOf('ai-analysis__section-label', markerEnd);
      final stop = label >= 0 ? label : markerEnd + 400;
      task = _inline(html.substring(markerEnd + 1, stop));
    }
  }
  if (solution.trim().isEmpty) return null;
  return {'solution': solution, 'task': task};
}

// ---------------------------------------------------------------------------
// Merging helpers
// ---------------------------------------------------------------------------

// reshak.ru often appends other editions, site navigation and legal text
// after the actual solution. Keep only the first solution block.
String _trimSolutionBoilerplate(String raw) {
  var end = raw.length;
  for (final marker in const [
    'Разбор подготовлен с помощью ИИ',
    'Решение #',
    'Кратко',
    '*Текст задания приводится',
    'Популярные решебники',
    'На главную',
    'ai-analysis__',
    '<section',
    '<details',
    'Оцени решение',
    'Показать полностью',
  ]) {
    final at = raw.indexOf(marker);
    if (at > 0 && at < end) end = at;
  }
  return raw.substring(0, end).trim();
}

Map<String, dynamic> _solutionFromText(String raw, int page) {
  var text = _latexToText(_trimSolutionBoilerplate(raw));
  text = _cleanMarkdown(text);

  String answer = '';
  final idx = _answerIndex(text);
  if (idx >= 0) {
    final tail = text.substring(idx);
    final colon = tail.indexOf(':');
    if (colon >= 0 && colon < 14) {
      var value = text.substring(idx + colon + 1).trim();
      final expl = value.toLowerCase().indexOf('объяснение');
      if (expl > 0) value = value.substring(0, expl).trim();
      final dash = value.indexOf('---');
      if (dash > 0) value = value.substring(0, dash).trim();
      value = value
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join(' ')
          .trim();
      if (value.length >= 2) answer = _truncate(value, 300);
    }
  }

  final steps = _stepsFromText(text);
  if (answer.isEmpty) {
    answer = steps.isEmpty ? 'См. решение' : _truncate(steps.first, 220);
  }
  return {'steps': steps, 'answer': answer};
}

Map<String, dynamic> _fallbackSolution(String hint, int page) {
  final steps = <String>[];
  if (hint.isNotEmpty) {
    for (final chunk in _splitSentences(hint)) {
      if (chunk.trim().isEmpty) continue;
      steps.add(_truncate(chunk.trim(), 300));
      if (steps.length >= 8) break;
    }
  }
  if (steps.isEmpty) {
    steps.add('Открой учебник на с. $page и выполни задание письменно.');
  } else {
    steps.add('Подробный разбор этой задачи — в учебнике на с. $page.');
  }
  return {'steps': steps, 'answer': 'См. разбор в учебнике, с. $page'};
}

List<String> _stepsFromText(String text) {
  final chunks = <String>[];
  for (final line in text.split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (t.length <= 320) {
      chunks.add(t);
    } else {
      chunks.addAll(_splitSentences(t));
    }
  }
  if (chunks.isEmpty) return ['См. решение'];
  const limit = 20;
  if (chunks.length <= limit) return chunks;
  return [
    ...chunks.take(limit - 1),
    chunks.skip(limit - 1).join(' '),
  ];
}

String _tidyCondition(String value, int number) {
  var t = value.trim();
  t = t.replaceFirst(RegExp('^$number\\s*[.)]?\\s*'), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

String _inline(String html) {
  var body = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ')
      .replaceAllMapped(RegExp(r'<sup>\s*0\s*</sup>'), (_) => '°')
      .replaceAllMapped(
          RegExp(r'<sup>\s*([123])\s*</sup>'),
          (m) => const {'1': '¹', '2': '²', '3': '³'}[m[1]] ?? m[0]!)
      .replaceAllMapped(RegExp(r'<img[^>]*alt="([^"]*)"[^>]*>'),
          (m) => ' ${m[1]} ')
      .replaceAll(
        RegExp(
            r'<\s*(br|/p|/div|/li|/tr|/h[1-6]|/table|/ul|/ol)\s*/?\s*>',
            caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');
  return _clean(body);
}

String _htmlToText(String html) => _inline(html);

// ---------------------------------------------------------------------------
// LaTeX / Markdown cleanup
// ---------------------------------------------------------------------------

const _commands = <String, String>{
  r'\cdot': '·',
  r'\times': '×',
  r'\div': ':',
  r'\pm': '±',
  r'\mp': '∓',
  r'\ge': '≥',
  r'\geq': '≥',
  r'\le': '≤',
  r'\leq': '≤',
  r'\ne': '≠',
  r'\neq': '≠',
  r'\approx': '≈',
  r'\equiv': '≡',
  r'\Rightarrow': '⇒',
  r'\Leftarrow': '⇐',
  r'\Leftrightarrow': '⇔',
  r'\to': '→',
  r'\rightarrow': '→',
  r'\uparrow': '↑',
  r'\downarrow': '↓',
  r'\in': '∈',
  r'\notin': '∉',
  r'\subset': '⊂',
  r'\cup': '∪',
  r'\cap': '∩',
  r'\varnothing': '∅',
  r'\emptyset': '∅',
  r'\angle': '∠',
  r'\triangle': '△',
  r'\perp': '⊥',
  r'\parallel': '∥',
  r'\sim': '∼',
  r'\cong': '≅',
  r'\pi': 'π',
  r'\alpha': 'α',
  r'\beta': 'β',
  r'\gamma': 'γ',
  r'\delta': 'δ',
  r'\epsilon': 'ε',
  r'\varepsilon': 'ε',
  r'\zeta': 'ζ',
  r'\eta': 'η',
  r'\theta': 'θ',
  r'\lambda': 'λ',
  r'\mu': 'μ',
  r'\nu': 'ν',
  r'\xi': 'ξ',
  r'\rho': 'ρ',
  r'\sigma': 'σ',
  r'\tau': 'τ',
  r'\phi': 'φ',
  r'\varphi': 'φ',
  r'\chi': 'χ',
  r'\psi': 'ψ',
  r'\omega': 'ω',
  r'\Gamma': 'Γ',
  r'\Delta': 'Δ',
  r'\Sigma': 'Σ',
  r'\Omega': 'Ω',
  r'\circ': '°',
  r'\degree': '°',
};

String _latexToText(String input) {
  var s = input;
  s = s.replaceAll(r'$$', ' ');
  s = s.replaceAll(r'\(', ' ');
  s = s.replaceAll(r'\)', ' ');
  s = s.replaceAll(r'\[', ' ');
  s = s.replaceAll(r'\]', ' ');
  s = s.replaceAll(r'\%', '%');

  // \frac{a}{b} and \sqrt{a}, including a few nesting levels.
  for (var pass = 0; pass < 6; pass++) {
    final before = s;
    s = s.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'),
      (m) => '(${m[1]})/(${m[2]})',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]*)\}'),
      (m) => '√(${m[1]})',
    );
    if (s == before) break;
  }

  // Superscripts and subscripts.
  s = s.replaceAll('^\\circ', '°');
  s = s.replaceAllMapped(RegExp(r'\^\{?([0-9])\}?'), (m) {
    const sup = {'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'};
    return sup[m[1]] ?? m[0]!;
  });
  s = s.replaceAllMapped(RegExp(r'\^\{([^{}]*)\}'), (m) => '^(${m[1]})');
  s = s.replaceAllMapped(RegExp(r'_\{?([0-9])\}?'), (m) {
    const sub = {'0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉'};
    return sub[m[1]] ?? m[0]!;
  });
  s = s.replaceAllMapped(RegExp(r'_\{([^{}]*)\}'), (m) => '_(${m[1]})');

  // \vec{a} -> a→ ; \overline{AB} -> AB ; \text{...} -> contents.
  s = s.replaceAllMapped(RegExp(r'\\vec\{([^{}]*)\}'), (m) => '${m[1]}→');
  s = s.replaceAllMapped(RegExp(r'\\overline\{([^{}]*)\}'), (m) => m[1]!);
  s = s.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf|mathit|operatorname)\{([^{}]*)\}'),
      (m) => m[1]!);

  for (final entry in _commands.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }

  // Formatting helpers and leftovers.
  s = s.replaceAll(RegExp(r'\\(left|right|big|Big|bigl|bigr)\b'), '');
  s = s.replaceAll(RegExp(r'\\[,;:! ]'), ' ');
  s = s.replaceAll(RegExp(r'\\([a-zA-Z]+)'), ' ');
  s = s.replaceAll(RegExp(r'[{}]'), '');
  s = s.replaceAll(RegExp(r'\$'), '');
  return s;
}

String _cleanMarkdown(String input) {
  var s = input;
  s = s.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
  s = s.replaceAll('**', '');
  s = s.replaceAll('__', '');
  s = s.replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ');
  s = s.replaceAll(RegExp(r'^\s*---+\s*$', multiLine: true), '');
  return s
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
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
      .replaceAll('&times;', '×')
      .replaceAll('&minus;', '−')
      .replaceAll('&plusmn;', '±')
      .replaceAll('&deg;', '°')
      .replaceAll('&larr;', '←')
      .replaceAll('&rarr;', '→')
      .replaceAll('&#183;', '·')
      .replaceAll('&#x25CF;', '')
      .replaceAll(RegExp(r'&#x[0-9A-Fa-f]+;'), ' ')
      .replaceAll(RegExp(r'&#\d+;'), ' ')
      .replaceAll(RegExp(r'&[a-zA-Z]+;'), ' ');
  t = t
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
  return t.trim();
}

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
  final share2 = text.indexOf('Поделиться');
  if (share2 >= 0 && text.substring(share2).length < 40) {
    text = text.substring(0, share2);
  }
  return text.trimRight();
}

// ---------------------------------------------------------------------------
// Similarity (used to make sure a solution belongs to the same task)
// ---------------------------------------------------------------------------

const _stop = <String>{
  'дан', 'дана', 'дано', 'даны', 'докажите', 'доказать', 'постройте',
  'построить', 'найдите', 'найти', 'что', 'чтобы', 'если', 'то', 'и', 'в',
  'на', 'из', 'с', 'для', 'при', 'около', 'через', 'или', 'а', 'б',
  'как', 'какие', 'какой', 'какая', 'который', 'которая', 'которые', 'это',
  'рис', 'рисунке', 'рисунок', 'задача', 'задаче', 'задание', 'ответ',
  'решение', 'пусть', 'тогда', 'так', 'же', 'не', 'ни', 'по', 'к', 'от',
  'до', 'за', 'над', 'под', 'без', 'у', 'о', 'об', 'во', 'со',
};

// Finds the last standalone "ответ:" label (so that words like
// "соответственно" do not count as an answer marker).
int _answerIndex(String text) {
  final re = RegExp(r'ответ\s*:', caseSensitive: false);
  final letter = RegExp(r'[А-Яа-яЁёA-Za-z]');
  var found = -1;
  for (final m in re.allMatches(text)) {
    final before = m.start == 0 ? ' ' : text[m.start - 1];
    if (letter.hasMatch(before)) continue;
    found = m.start;
  }
  return found;
}

Set<String> _tokens(String value) {
  final norm = value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
      .trim();
  final out = <String>{};
  for (final word in norm.split(' ')) {
    if (word.isEmpty) continue;
    if (word.length <= 2) continue;
    if (_stop.contains(word)) continue;
    final stem = word.length >= 6 ? word.substring(0, 5) : word;
    out.add(stem);
  }
  return out;
}

double _similar(String a, String b) {
  final A = _tokens(a);
  final B = _tokens(b);
  if (A.isEmpty || B.isEmpty) return 0;
  final common = A.intersection(B).length;
  final min = A.length < B.length ? A.length : B.length;
  return common / min;
}

/// Number of distinct condition words that also occur in the candidate
/// solution. Used to reject solutions that belong to a neighbouring exercise.
int _keywordHits(String condition, String candidate) {
  final cond = _tokens(condition);
  final cand = _tokens(candidate);
  var hits = 0;
  for (final stem in cond) {
    if (cand.contains(stem)) hits++;
  }
  return hits;
}

double _reshakScore(String solution, String task, String condition) {
  final a = _similar(task, condition);
  final b = _similar(solution, condition);
  final score = a > b ? a : b;
  return score;
}

String _truncate(String text, int max) {
  if (text.length <= max) return text;
  var cut = text.substring(0, max);
  final space = cut.lastIndexOf(' ');
  if (space > max * 0.6) cut = cut.substring(0, space);
  return '${cut.trimRight()}…';
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

String _ranges(List<int> numbers) {
  final sorted = [...numbers]..sort();
  final out = <String>[];
  var start = sorted.first;
  var prev = start;
  for (var i = 1; i < sorted.length; i++) {
    final n = sorted[i];
    if (n == prev + 1) {
      prev = n;
      continue;
    }
    out.add(start == prev ? '$start' : '$start–$prev');
    start = n;
    prev = n;
  }
  out.add(start == prev ? '$start' : '$start–$prev');
  return out.join(', ');
}
