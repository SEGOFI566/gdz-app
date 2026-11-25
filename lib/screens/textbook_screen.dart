import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import 'task_screen.dart';

class TextbookScreen extends StatefulWidget {
  const TextbookScreen({super.key, required this.textbookId});

  final String textbookId;

  @override
  State<TextbookScreen> createState() => _TextbookScreenState();
}

class _TextbookScreenState extends State<TextbookScreen> {
  /// 40 tasks = 10 rows of the 4-column grid.
  static const _pageSize = 40;

  final _gridKey = GlobalKey();
  final _searchController = TextEditingController();
  int _page = 0;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TextbookScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textbookId != widget.textbookId) {
      _page = 0;
      _query = '';
      _searchController.clear();
    }
  }

  /// Фильтр внутри учебника: номер («527», «№ 527») или слово из условия.
  List<TaskItem> _matches(List<TaskItem> tasks, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final number = AppState.numberQuery(trimmed);
    if (number != null) {
      final exact = <TaskItem>[];
      final partial = <TaskItem>[];
      for (final task in tasks) {
        if (task.number == number) {
          exact.add(task);
        } else if (task.number.contains(number)) {
          partial.add(task);
        }
      }
      return [...exact, ...partial];
    }
    final text = trimmed.toLowerCase();
    return tasks
        .where((task) => task.condition.toLowerCase().contains(text))
        .toList();
  }

  void _openTask(TaskItem task) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskScreen(taskId: task.id)),
    );
  }

  /// Enter открывает единственное найденное задание.
  void _openFirstMatch(List<TaskItem> matches) {
    if (matches.length == 1) _openTask(matches.first);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _openPage(int page) {
    setState(() => _page = page);
    final anchor = _gridKey.currentContext;
    if (anchor != null) {
      Scrollable.ensureVisible(
        anchor,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Быстрый выбор страницы: сетка всех страниц с диапазонами заданий.
  Future<void> _pickPage(int pageCount, Color color, int total) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _PagePicker(
        pageCount: pageCount,
        current: _page.clamp(0, pageCount - 1).toInt(),
        pageSize: _pageSize,
        total: total,
        color: color,
      ),
    );
    if (selected != null && mounted) _openPage(selected);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final textbook = state.textbookById(widget.textbookId);
    final subject =
        textbook == null ? null : state.subjectById(textbook.subjectId);
    final tasks = state.tasksFor(widget.textbookId);
    final color = textbook?.color ?? kAccent;

    if (textbook == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Учебник')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Учебник не найден',
          message: 'Попробуй открыть его из списка предметов.',
        ),
      );
    }

    final pageCount =
        tasks.isEmpty ? 1 : (tasks.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(0, pageCount - 1).toInt();
    final first = page * _pageSize;
    final visible = tasks.skip(first).take(_pageSize).toList();
    final last = first + visible.length;

    final query = _query.trim();
    final searching = query.isNotEmpty;
    final matches = searching ? _matches(tasks, query) : const <TaskItem>[];
    final shown = searching ? matches : visible;
    final exactNumber = searching ? AppState.numberQuery(query) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subject?.name ?? textbook.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _BookHeader(textbook: textbook, taskCount: tasks.length),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (_) => _openFirstMatch(matches),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Быстрый поиск: № 527 или слово из задания',
              prefixIcon: Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              suffixIcon: searching
                  ? IconButton(
                      tooltip: 'Сбросить поиск',
                      onPressed: _clearSearch,
                      icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            key: _gridKey,
            children: [
              Text(
                searching ? 'Результаты' : 'Задания',
                style: sectionTitleStyle(context),
              ),
              const Spacer(),
              if (searching)
                Text(
                  'найдено ${matches.length}',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              else if (tasks.isEmpty)
                Text(
                  plural(tasks.length, 'задание', 'задания', 'заданий'),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              else
                _RangePill(
                  label: '${first + 1}–$last из ${tasks.length}',
                  color: color,
                  onTap: () => _pickPage(pageCount, color, tasks.length),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const _HintCard(
              icon: Icons.pending_actions_rounded,
              text: 'Решения для этого учебника ещё готовятся.',
            )
          else if (searching && matches.isEmpty)
            _HintCard(
              icon: Icons.search_off_rounded,
              text: 'По запросу «$query» ничего не нашлось. '
                  'Проверь номер задания или введи слово из условия.',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shown.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final task = shown[index];
                final favorite = state.isFavorite(task.id);
                return _TaskNumber(
                  task: task,
                  color: color,
                  favorite: favorite,
                  highlight: searching && task.number == exactNumber,
                  onTap: () => _openTask(task),
                );
              },
            ),
          if (!searching && pageCount > 1) ...[
            const SizedBox(height: 18),
            _Pager(
              page: page,
              pageCount: pageCount,
              color: color,
              onChanged: _openPage,
              onPick: () => _pickPage(pageCount, color, tasks.length),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.textbook, required this.taskCount});

  final Textbook textbook;
  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final color = textbook.color;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.25)!],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded,
                    color: Colors.white, size: 30),
                const SizedBox(height: 6),
                Text(
                  '${textbook.grade} класс',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textbook.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  textbook.author,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      text: '${textbook.year}',
                    ),
                    _InfoChip(
                      icon: Icons.apartment_rounded,
                      text: textbook.publisher,
                    ),
                    _InfoChip(
                      icon: Icons.task_alt_rounded,
                      text: plural(taskCount, 'задание', 'задания', 'заданий'),
                    ),
                    if (textbook.pages > 0)
                      _InfoChip(
                        icon: Icons.auto_stories_rounded,
                        text: '${textbook.pages} с.',
                      ),
                    if (textbook.isbn.isNotEmpty)
                      _InfoChip(
                        icon: Icons.qr_code_2_rounded,
                        text: 'ISBN ${textbook.isbn}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskNumber extends StatelessWidget {
  const _TaskNumber({
    required this.task,
    required this.color,
    required this.favorite,
    required this.onTap,
    this.highlight = false,
  });

  final TaskItem task;
  final Color color;
  final bool favorite;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? color.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight ? color : Theme.of(context).colorScheme.outlineVariant,
              width: highlight ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  task.number,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: highlight ? color : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (favorite)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Icon(Icons.bookmark_rounded,
                      size: 12, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.unfold_more_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _PagePicker extends StatelessWidget {
  const _PagePicker({
    required this.pageCount,
    required this.current,
    required this.pageSize,
    required this.total,
    required this.color,
  });

  final int pageCount;
  final int current;
  final int pageSize;
  final int total;
  final Color color;

  String _range(int page) {
    final first = page * pageSize + 1;
    final last = (first + pageSize - 1).clamp(0, total);
    return '$first–$last';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Выбор страницы', style: sectionTitleStyle(context)),
                  const Spacer(),
                  Text(
                    '$total заданий',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Нажми на страницу, чтобы сразу перейти к её заданиям.',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: pageCount,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, index) => _PageTile(
                    page: index,
                    range: _range(index),
                    selected: index == current,
                    color: color,
                    onTap: () => Navigator.of(context).pop(index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.page,
    required this.range,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final int page;
  final String range;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${page + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    range,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.color,
    required this.onChanged,
    required this.onPick,
  });

  final int page;
  final int pageCount;
  final Color color;
  final ValueChanged<int> onChanged;
  final VoidCallback onPick;

  /// Page numbers with gaps collapsed to "…" for long books (535 tasks = 14
  /// pages), so the control always fits on one or two lines.
  List<int?> get _items {
    if (pageCount <= 7) {
      return [for (var i = 0; i < pageCount; i++) i];
    }
    final wanted = <int>{0, pageCount - 1};
    for (var delta = -2; delta <= 2; delta++) {
      wanted.add(page + delta);
    }
    final valid = wanted.where((i) => i >= 0 && i < pageCount).toList()..sort();
    final items = <int?>[];
    int? previous;
    for (final index in valid) {
      if (previous != null && index - previous > 1) items.add(null);
      items.add(index);
      previous = index;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _PagerArrow(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Предыдущая страница',
            enabled: page > 0,
            onTap: () => onChanged(page - 1),
          ),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in _items)
                  if (item == null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text('…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    )
                  else
                    _PageChip(
                      label: '${item + 1}',
                      selected: item == page,
                      color: color,
                      onTap: () => onChanged(item),
                    ),
              ],
            ),
          ),
          _PagerArrow(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Следующая страница',
            enabled: page < pageCount - 1,
            onTap: () => onChanged(page + 1),
          ),
          IconButton(
            tooltip: 'Все страницы',
            onPressed: onPick,
            icon: const Icon(Icons.grid_view_rounded),
            color: color,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PagerArrow extends StatelessWidget {
  const _PagerArrow({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      color: Theme.of(context).colorScheme.onSurface,
      disabledColor: const Color(0xFFC9C5D6),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
