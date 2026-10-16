import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'providers.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final db = await AppDatabase.open();
  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const EntreApp(),
  ));
}

class EntreApp extends StatelessWidget {
  const EntreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF8A5A44));
    return MaterialApp(
      title: 'Entre Sales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      ),
      home: const AppShell(),
    );
  }
}
