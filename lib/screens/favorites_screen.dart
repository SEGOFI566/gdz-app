import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_tile.dart';
import 'task_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tasks = state.favoriteTasks;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Избранное',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kInk,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Задания, которые ты сохранил для повторения',
            style: TextStyle(fontSize: 13, color: kMuted),
          ),
          const SizedBox(height: 20),
          if (tasks.isEmpty)
            const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Пока пусто',
              message: 'Открой задание и нажми на закладку в правом верхнем '
                  'углу — оно появится здесь.',
            )
          else ...[
            Row(
              children: [
                Text('Сохранено', style: sectionTitleStyle(context)),
                const Spacer(),
                Text(
                  plural(tasks.length, 'задание', 'задания', 'заданий'),
                  style: const TextStyle(fontSize: 13, color: kMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final task in tasks) ...[
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
}
