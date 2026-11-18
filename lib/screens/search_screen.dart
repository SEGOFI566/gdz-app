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
    final results = state.search(_query);
    final trimmed = _query.trim();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Поиск',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kInk,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Номер задания, условие, учебник или тема. Номер можно вводить без «№».',
            style: TextStyle(fontSize: 13, color: kMuted),
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
              prefixIcon: const Icon(Icons.search_rounded, color: kMuted),
              suffixIcon: trimmed.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить',
                      onPressed: () => _setQuery(''),
                      icon: const Icon(Icons.close_rounded, color: kMuted),
                    ),
            ),
          ),
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
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE7E4EF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kInk,
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
                  style: const TextStyle(fontSize: 13, color: kMuted),
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
}
