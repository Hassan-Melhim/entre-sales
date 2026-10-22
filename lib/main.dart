import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'data/sqlite/app_database.dart';
import 'data/sqlite/repositories/sqlite_settings_repository.dart';
import 'domain/repositories/settings_repository.dart';
import 'presentation/app.dart';
import 'presentation/providers.dart';
import 'presentation/startup_error_app.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opens the right SQLite for the platform (browser, Android, Windows…).
  final Database db;
  final ThemeMode themeMode;
  try {
    db = await AppDatabase.open();
    final settings = SqliteSettingsRepository(db);
    themeMode = AppTheme.modeFromSetting(await settings.get(SettingKeys.themeMode));
  } catch (e) {
    // A message instead of a blank screen.
    runApp(StartupErrorApp(e));
    return;
  }

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      themeModeProvider.overrideWith((ref) => ThemeModeController(ref.watch(settingsRepositoryProvider), themeMode)),
    ],
    child: const EntreApp(),
  ));
}
