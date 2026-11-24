import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/android_download_card.dart';
import '../widgets/search_pill.dart';
import '../widgets/subject_card.dart';
import '../widgets/telegram_card.dart';
import 'textbooks_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final subjects = state.subjectsForGrade(state.grade);

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
                child: const Text(
                  'ГДЗ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Готовые домашние задания',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Выбери класс, предмет и задание',
                      style: TextStyle(fontSize: 13, color: kMuted),
                    ),
                  ],
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
          const SizedBox(height: 26),
          Row(
            children: [
              Text('Класс', style: sectionTitleStyle(context)),
              const Spacer(),
              Text(
                '${state.grade} класс',
                style: const TextStyle(
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
                    color: selected ? Colors.white : kInk,
                  ),
                  selectedColor: kAccent,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? kAccent : const Color(0xFFE7E4EF),
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
                style: const TextStyle(fontSize: 13, color: kMuted),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E4EF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, color: kMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Для этого класса материалы ещё готовятся. '
              'Попробуй выбрать другой класс.',
              style: TextStyle(fontSize: 13, color: kMuted, height: 1.4),
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
        color: kInk,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
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
