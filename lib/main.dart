import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/sqlite/app_database.dart';
import 'data/sqlite/repositories/sqlite_settings_repository.dart';
import 'domain/repositories/settings_repository.dart';
import 'presentation/app.dart';
import 'presentation/providers.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opens the right SQLite for the platform (browser, Android, Windows…).
  final db = await AppDatabase.open();
  final settings = SqliteSettingsRepository(db);
  final themeMode = AppTheme.modeFromSetting(await settings.get(SettingKeys.themeMode));

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      themeModeProvider.overrideWith((ref) => ThemeModeController(ref.watch(settingsRepositoryProvider), themeMode)),
    ],
    child: const EntreApp(),
  ));
}
