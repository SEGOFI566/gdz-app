import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/root_shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GdzApp());
}

class GdzApp extends StatefulWidget {
  const GdzApp({super.key});

  @override
  State<GdzApp> createState() => _GdzAppState();
}

class _GdzAppState extends State<GdzApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) => MaterialApp(
          title: 'ГДЗ — готовые домашние задания',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _state.themeMode,
          home: const RootShell(),
        ),
      ),
    );
  }
}
