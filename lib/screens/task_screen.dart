import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool _revealed = false;
  String? _markedRecentFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRecent());
  }

  @override
  void didUpdateWidget(covariant TaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _revealed = false;
      _markedRecentFor = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _markRecent());
    }
  }

  void _markRecent() {
    if (!mounted) return;
    if (_markedRecentFor == widget.taskId) return;
    _markedRecentFor = widget.taskId;
    AppScope.of(context).markRecent(widget.taskId);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final task = state.taskById(widget.taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Задание')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Задание не найдено',
          message: 'Вернись к списку заданий и выбери другое.',
        ),
      );
    }

    final textbook = state.textbookById(task.textbookId);
    final subject =
        textbook == null ? null : state.subjectById(textbook.subjectId);
    final accent = subject?.color ?? kAccent;
    final favorite = state.isFavorite(task.id);
    final solution = task.solutions.isNotEmpty ? task.solutions.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Задание № ${task.number}'),
        actions: [
          IconButton(
            tooltip:
                favorite ? 'Убрать из избранного' : 'Сохранить в избранное',
            onPressed: () => state.toggleFavorite(task.id),
            icon: Icon(
              favorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: favorite ? accent : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (subject != null)
                _Chip(icon: subject.iconData, text: subject.name, color: accent),
              if (textbook != null)
                _Chip(
                  icon: Icons.school_rounded,
                  text: '${textbook.grade} класс',
                  color: accent,
                ),
              if (task.page > 0)
                _Chip(
                  icon: Icons.description_rounded,
                  text: 'стр. ${task.page}',
                  color: accent,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        'Условие',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '№ ${task.number}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  task.condition,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (textbook != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${textbook.title} · ${textbook.author}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (solution == null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Решение для этого задания ещё готовится.',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _revealed
                  ? _SolutionView(
                      key: const ValueKey('solution'),
                      solution: solution,
                      accent: accent,
                      onHide: () => setState(() => _revealed = false),
                    )
                  : _LockedSolution(
                      key: const ValueKey('locked'),
                      accent: accent,
                      onReveal: () => setState(() => _revealed = true),
                    ),
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Сначала попробуй решить сам, а решение используй для '
                    'проверки. Так знания останутся с тобой.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedSolution extends StatelessWidget {
  const _LockedSolution({
    super.key,
    required this.accent,
    required this.onReveal,
  });

  final Color accent;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.10),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.visibility_rounded, color: accent, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'Решение готово',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Пошаговый разбор с ответом и пояснениями',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onReveal,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('Показать решение'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionView extends StatelessWidget {
  const _SolutionView({
    super.key,
    required this.solution,
    required this.accent,
    required this.onHide,
  });

  final Solution solution;
  final Color accent;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Решение', style: sectionTitleStyle(context)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onHide,
                    icon: const Icon(Icons.visibility_off_rounded, size: 16),
                    label: Text('Скрыть'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      textStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < solution.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          solution.steps[i],
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ответ:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        solution.answer,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.verified_user_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${solution.author} · проверено редакцией',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 3),
            Text(
              solution.rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
