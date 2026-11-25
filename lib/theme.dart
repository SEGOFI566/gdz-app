import 'package:flutter/material.dart';

const Color kAccent = Color(0xFF4F46E5);

// Legacy color constants kept for compatibility; prefer Theme.of(context) for
// surfaces/text so dark mode works.
const Color kInk = Color(0xFF1B1B22);
const Color kMuted = Color(0xFF6E6A78);
const Color kPaper = Color(0xFFF6F5FA);

ThemeData buildTheme() => _build(Brightness.light);
ThemeData buildDarkTheme() => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: brightness,
  );
  final bg = isDark ? const Color(0xFF121218) : kPaper;
  final card = isDark ? const Color(0xFF1C1C24) : Colors.white;
  final border = isDark ? const Color(0xFF2E2E3A) : const Color(0xFFE7E4EF);
  final text = isDark ? const Color(0xFFF1F1F5) : kInk;
  final muted = isDark ? const Color(0xFFA1A1AA) : kMuted;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme.copyWith(
      surface: card,
      onSurface: text,
      onSurfaceVariant: muted,
      outlineVariant: border,
      surfaceContainerLow: isDark ? const Color(0xFF181820) : kPaper,
    ),
    scaffoldBackgroundColor: bg,
    cardColor: card,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: text,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: kAccent.withValues(alpha: isDark ? 0.22 : 0.12),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? kAccent : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? kAccent : muted, size: 24);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: muted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kAccent, width: 1.6),
      ),
    ),
    dividerColor: border,
  );
}

TextStyle sectionTitleStyle(BuildContext context) {
  final color = Theme.of(context).colorScheme.onSurface;
  return Theme.of(context).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.2,
      );
}

String plural(int count, String one, String few, String many) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return '$count $one';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$count $few';
  }
  return '$count $many';
}
