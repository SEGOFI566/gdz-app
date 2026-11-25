import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/android_download_card.dart';
import '../widgets/search_pill.dart';
import '../widgets/subject_card.dart';
import '../widgets/task_tile.dart';
import '../widgets/telegram_card.dart';
import 'task_screen.dart';
import 'textbooks_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final subjects = state.subjectsForGrade(state.grade);
    final recent = state.recentTasks.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6D5BF6), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  'ГДЗ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Готовые домашние задания',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Выбери класс, предмет и задание',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
                onPressed: () => state.setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                ),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SearchPill(onTap: onOpenSearch),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            const TelegramCard(),
            const SizedBox(height: 10),
            const AndroidDownloadCard(),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(
              children: [
                Text('Недавно смотрели', style: sectionTitleStyle(context)),
                const Spacer(),
                Text(
                  plural(recent.length, 'задание', 'задания', 'заданий'),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final task in recent) ...[
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
          const SizedBox(height: 26),
          Row(
            children: [
              Text('Класс', style: sectionTitleStyle(context)),
              const Spacer(),
              Text(
                '${state.grade} класс',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final grade = 5 + index;
                final selected = grade == state.grade;
                return ChoiceChip(
                  label: Text('$grade'),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => state.setGrade(grade),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  selectedColor: kAccent,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: selected ? kAccent : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                );
              },
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text('Предметы', style: sectionTitleStyle(context)),
              const Spacer(),
              Text(
                plural(subjects.length, 'предмет', 'предмета', 'предметов'),
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            const _EmptyGrade()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subjects.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.12,
              ),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return SubjectCard(
                  subject: subject,
                  textbookCount:
                      state.textbooksFor(subject.id, state.grade).length,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TextbooksScreen(
                          subjectId: subject.id,
                          grade: state.grade,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 26),
          const _HowItWorksCard(),
        ],
      ),
    );
  }
}

class _EmptyGrade extends StatelessWidget {
  const _EmptyGrade();

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
          Icon(Icons.hourglass_empty_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Для этого класса материалы ещё готовятся. '
              'Попробуй выбрать другой класс.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B22),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF9B8CFF), size: 20),
              SizedBox(width: 8),
              Text(
                'Собственная база решений',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Все решения проверены редакцией: пошаговый разбор, ответ '
            'и пояснения. Каталог хранится в приложении и работает без '
            'интернета.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
