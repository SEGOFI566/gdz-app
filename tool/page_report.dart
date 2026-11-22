import 'dart:convert';
import 'dart:io';

void main() {
  final json = jsonDecode(File('assets/data/catalog.json').readAsStringSync())
      as Map<String, dynamic>;
  final tasks = json['tasks'] as List<dynamic>;
  final by = <String, Map<String, dynamic>>{};
  for (final t in tasks) {
    final id = t['textbookId'] as String;
    final e = by.putIfAbsent(id, () {
      return {'n': 0, 'min': 99999, 'max': 0, 'pages': <int>{}};
    });
    e['n'] = (e['n'] as int) + 1;
    final p = (t['page'] as num?)?.toInt() ?? 0;
    if (p < (e['min'] as int)) e['min'] = p;
    if (p > (e['max'] as int)) e['max'] = p;
    (e['pages'] as Set<int>).add(p);
  }
  final out = StringBuffer();
  final ids = by.keys.toList()..sort();
  for (final id in ids) {
    final e = by[id]!;
    out.writeln('$id tasks=${e['n']} pages=${e['min']}..${e['max']} '
        'unique=${(e['pages'] as Set<int>).length}');
  }
  File('tool/page_report.txt').writeAsStringSync(out.toString());
  stdout.writeln('OK ${by.length} textbooks');
}
