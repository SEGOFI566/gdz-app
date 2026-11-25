import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_tile.dart';
import 'task_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  int? _grade;
  String? _subjectId;
  String? _textbookId;

  static const _popular = [
    '№ 527',
    'уравнение',
    'Пифагор',
    'Крещение Руси',
    'прилагательное',
    'Present Simple',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    _controller.text = value;
    _controller.selection =
        TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final results = state.search(
      _query,
      grade: _grade,
      subjectId: _subjectId,
      textbookId: _textbookId,
    );
    final trimmed = _query.trim();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text(
            'Поиск',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Номер задания, условие, учебник или тема. Номер можно вводить без «№».',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (_) {
              // Единственный результат открываем сразу — это и есть быстрый поиск.
              if (results.length == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskScreen(taskId: results.first.id),
                  ),
                );
              }
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Например: № 124 или уравнение',
              prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              suffixIcon: trimmed.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить',
                      onPressed: () => _setQuery(''),
                      icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFilters(state),
          const SizedBox(height: 22),
          if (trimmed.isEmpty) ...[
            Text('Популярные запросы', style: sectionTitleStyle(context)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final query in _popular)
                  ActionChip(
                    label: Text(query),
                    onPressed: () => _setQuery(query),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: const BorderSide(color: Color(0xFFE7E4EF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ] else if (results.isEmpty)
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Ничего не найдено',
              message: 'Попробуй другой номер задания, тему или фамилию '
                  'автора учебника.',
            )
          else ...[
            Row(
              children: [
                Text('Результаты', style: sectionTitleStyle(context)),
                const Spacer(),
                Text(
                  plural(results.length, 'задание', 'задания', 'заданий'),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final task in results) ...[
              TaskTile(
                task: task,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskScreen(taskId: task.id),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(AppState state) {
    final data = state.catalog;
    if (data == null) return const SizedBox.shrink();

    final subjects = _grade == null
        ? data.subjects
        : data.subjectsForGrade(_grade!);
    final textbooks = data.textbooks.where((t) {
      if (_grade != null && t.grade != _grade) return false;
      if (_subjectId != null && t.subjectId != _subjectId) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final gradeLabel = _grade == null ? 'Все классы' : '$_grade класс';
    final subjectLabel = _subjectId == null
        ? 'Все предметы'
        : (data.subjectById[_subjectId]?.name ?? 'Предмет');
    final textbookLabel = _textbookId == null
        ? 'Все учебники'
        : (data.textbookById[_textbookId]?.title ?? 'Учебник');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterMenu<int?>(
          label: gradeLabel,
          active: _grade != null,
          items: [null, for (var g = 5; g <= 11; g++) g],
          itemLabel: (v) => v == null ? 'Все классы' : '$v класс',
          onSelected: (v) => setState(() {
            _grade = v;
            final newSubjects =
                v == null ? data.subjects : data.subjectsForGrade(v);
            if (_subjectId != null &&
                !newSubjects.any((s) => s.id == _subjectId)) {
              _subjectId = null;
              _textbookId = null;
            }
            final newTextbooks = data.textbooks.where((t) {
              if (v != null && t.grade != v) return false;
              if (_subjectId != null && t.subjectId != _subjectId) return false;
              return true;
            });
            if (_textbookId != null &&
                !newTextbooks.any((t) => t.id == _textbookId)) {
              _textbookId = null;
            }
          }),
        ),
        _filterMenu<String?>(
          label: subjectLabel,
          active: _subjectId != null,
          items: [null, ...subjects.map((s) => s.id)],
          itemLabel: (v) =>
              v == null ? 'Все предметы' : (data.subjectById[v]?.name ?? v),
          onSelected: (v) => setState(() {
            _subjectId = v;
            final newTextbooks = data.textbooks.where((t) {
              if (_grade != null && t.grade != _grade) return false;
              if (v != null && t.subjectId != v) return false;
              return true;
            });
            if (_textbookId != null &&
                !newTextbooks.any((t) => t.id == _textbookId)) {
              _textbookId = null;
            }
          }),
        ),
        _filterMenu<String?>(
          label: textbookLabel,
          active: _textbookId != null,
          items: [null, ...textbooks.map((t) => t.id)],
          itemLabel: (v) {
            if (v == null) return 'Все учебники';
            final t = data.textbookById[v];
            if (t == null) return v;
            final title = t.title;
            return title.length > 36 ? '${title.substring(0, 35)}…' : title;
          },
          onSelected: (v) => setState(() {
            _textbookId = v;
            if (v != null) {
              final t = data.textbookById[v];
              if (t != null) {
                _grade = t.grade;
                _subjectId = t.subjectId;
              }
            }
          }),
        ),
        if (_grade != null || _subjectId != null || _textbookId != null)
          ActionChip(
            label: Text('Сбросить'),
            onPressed: () => setState(() {
              _grade = null;
              _subjectId = null;
              _textbookId = null;
            }),
            backgroundColor: Theme.of(context).colorScheme.surface,
            side: const BorderSide(color: Color(0xFFE7E4EF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _filterMenu<T>({
    required String label,
    required bool active,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelected,
  }) {
    final fg = active ? kAccent : Theme.of(context).colorScheme.onSurface;
    final bg = active ? kAccent.withValues(alpha: 0.10) : Colors.white;
    final border =
        active ? kAccent.withValues(alpha: 0.35) : Theme.of(context).colorScheme.outlineVariant;
    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item,
            child: Text(
              itemLabel(item),
              style: TextStyle(fontSize: 14),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}
