import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/textbook_card.dart';
import 'textbook_screen.dart';

class TextbooksScreen extends StatelessWidget {
  const TextbooksScreen({
    super.key,
    required this.subjectId,
    required this.grade,
  });

  final String subjectId;
  final int grade;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final subject = state.subjectById(subjectId);
    final textbooks = state.textbooksFor(subjectId, grade);
    final color = subject?.color ?? kAccent;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject?.name ?? 'Предмет'),
            Text(
              '$grade класс',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kMuted,
              ),
            ),
          ],
        ),
      ),
      body: textbooks.isEmpty
          ? const EmptyState(
              icon: Icons.menu_book_rounded,
              title: 'Учебники ещё не добавлены',
              message: 'Для этого класса материалы появятся позже. '
                  'Выбери другой класс на главном экране.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: textbooks.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SubjectHeader(
                    title: subject?.name ?? 'Предмет',
                    grade: grade,
                    count: textbooks.length,
                    color: color,
                    icon: subject?.iconData ?? Icons.menu_book_rounded,
                  );
                }
                final textbook = textbooks[index - 1];
                return TextbookCard(
                  textbook: textbook,
                  taskCount: state.catalog?.taskCountFor(textbook.id) ?? 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TextbookScreen(textbookId: textbook.id),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({
    required this.title,
    required this.grade,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final int grade;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.22)!],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$grade класс',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
