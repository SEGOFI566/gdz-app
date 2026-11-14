import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import 'task_screen.dart';

class TextbookScreen extends StatelessWidget {
  const TextbookScreen({super.key, required this.textbookId});

  final String textbookId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final textbook = state.textbookById(textbookId);
    final subject =
        textbook == null ? null : state.subjectById(textbook.subjectId);
    final tasks = state.tasksFor(textbookId);
    final color = textbook?.color ?? kAccent;

    if (textbook == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Учебник')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Учебник не найден',
          message: 'Попробуй открыть его из списка предметов.',
        ),
      );
    }

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
          const SizedBox(height: 22),
          Row(
            children: [
              Text('Задания', style: sectionTitleStyle(context)),
              const Spacer(),
              Text(
                plural(tasks.length, 'задание', 'задания', 'заданий'),
                style: const TextStyle(fontSize: 13, color: kMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE7E4EF)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: kMuted),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Решения для этого учебника ещё готовятся.',
                      style: TextStyle(fontSize: 13, color: kMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final favorite = state.isFavorite(task.id);
                return _TaskNumber(
                  task: task,
                  color: color,
                  favorite: favorite,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskScreen(taskId: task.id),
                      ),
                    );
                  },
                );
              },
            ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E4EF)),
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
                const Icon(Icons.menu_book_rounded,
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  textbook.author,
                  style: const TextStyle(fontSize: 13, color: kMuted),
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
        color: kPaper,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: kMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: kMuted),
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
  });

  final TaskItem task;
  final Color color;
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E4EF)),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  task.number,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kInk,
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
