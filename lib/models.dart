import 'package:flutter/material.dart';

/// Модели каталога ГДЗ: предмет → учебник → задание → решение.

Color parseHexColor(String hex) {
  var value = hex.replaceAll('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

const Map<String, IconData> _subjectIcons = {
  'calculate': Icons.calculate_rounded,
  'functions': Icons.functions_rounded,
  'change_history': Icons.change_history_rounded,
  'menu_book': Icons.menu_book_rounded,
  'auto_stories': Icons.auto_stories_rounded,
  'translate': Icons.translate_rounded,
  'science': Icons.science_rounded,
  'biotech': Icons.biotech_rounded,
  'account_balance': Icons.account_balance_rounded,
  'eco': Icons.eco_rounded,
  'computer': Icons.computer_rounded,
};

class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  final String id;
  final String name;
  final Color color;
  final String icon;

  IconData get iconData => _subjectIcons[icon] ?? Icons.book_rounded;

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      color: parseHexColor(json['color'] as String? ?? '#4F46E5'),
      icon: json['icon'] as String? ?? 'menu_book',
    );
  }
}

class Textbook {
  const Textbook({
    required this.id,
    required this.subjectId,
    required this.grade,
    required this.title,
    required this.author,
    required this.year,
    required this.publisher,
    required this.color,
    this.isbn = '',
    this.pages = 0,
  });

  final String id;
  final String subjectId;
  final int grade;
  final String title;
  final String author;
  final int year;
  final String publisher;
  final Color color;
  final String isbn;
  final int pages;

  factory Textbook.fromJson(Map<String, dynamic> json) {
    return Textbook(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      grade: (json['grade'] as num).toInt(),
      title: json['title'] as String,
      author: json['author'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      publisher: json['publisher'] as String? ?? '',
      color: parseHexColor(json['color'] as String? ?? '#4F46E5'),
      isbn: json['isbn'] as String? ?? '',
      pages: (json['pages'] as num?)?.toInt() ?? 0,
    );
  }
}

class Solution {
  const Solution({
    required this.id,
    required this.author,
    required this.rating,
    required this.steps,
    required this.answer,
  });

  final String id;
  final String author;
  final double rating;
  final List<String> steps;
  final String answer;

  factory Solution.fromJson(Map<String, dynamic> json) {
    return Solution(
      id: json['id'] as String,
      author: json['author'] as String? ?? 'Команда ГДЗ',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      steps: (json['steps'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      answer: json['answer'] as String? ?? '',
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.textbookId,
    required this.number,
    required this.page,
    required this.condition,
    required this.solutions,
  });

  final String id;
  final String textbookId;
  final String number;
  final int page;
  final String condition;
  final List<Solution> solutions;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      textbookId: json['textbookId'] as String,
      number: json['number'] as String,
      page: (json['page'] as num?)?.toInt() ?? 0,
      condition: json['condition'] as String,
      solutions: (json['solutions'] as List? ?? const [])
          .map((e) => Solution.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Catalog {
  Catalog({
    required this.subjects,
    required this.textbooks,
    required this.tasks,
  });

  final List<Subject> subjects;
  final List<Textbook> textbooks;
  final List<TaskItem> tasks;

  late final Map<String, Subject> subjectById = {
    for (final subject in subjects) subject.id: subject,
  };
  late final Map<String, Textbook> textbookById = {
    for (final textbook in textbooks) textbook.id: textbook,
  };
  late final Map<String, TaskItem> taskById = {
    for (final task in tasks) task.id: task,
  };

  factory Catalog.fromJson(Map<String, dynamic> json) {
    return Catalog(
      subjects: (json['subjects'] as List? ?? const [])
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList(),
      textbooks: (json['textbooks'] as List? ?? const [])
          .map((e) => Textbook.fromJson(e as Map<String, dynamic>))
          .toList(),
      tasks: (json['tasks'] as List? ?? const [])
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  List<Subject> subjectsForGrade(int grade) {
    final ids = textbooks
        .where((textbook) => textbook.grade == grade)
        .map((textbook) => textbook.subjectId)
        .toSet();
    return subjects.where((subject) => ids.contains(subject.id)).toList();
  }

  List<Textbook> textbooksFor(String subjectId, int grade) {
    final list = textbooks
        .where((textbook) =>
            textbook.subjectId == subjectId && textbook.grade == grade)
        .toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  List<TaskItem> tasksFor(String textbookId) {
    final list =
        tasks.where((task) => task.textbookId == textbookId).toList();
    list.sort((a, b) {
      final first = int.tryParse(a.number);
      final second = int.tryParse(b.number);
      if (first != null && second != null) return first.compareTo(second);
      return a.number.compareTo(b.number);
    });
    return list;
  }

  int taskCountFor(String textbookId) {
    return tasks.where((task) => task.textbookId == textbookId).length;
  }
}
