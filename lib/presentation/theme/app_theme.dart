import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light and dark themes, built from the same brand colour.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF8A5A44);

  static ThemeData light() => _build(Brightness.light, AppColors.light);
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Comfortable touch targets on the iPad, compact with a mouse.
      visualDensity: VisualDensity.adaptivePlatformDensity,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      extensions: [colors],
    );
  }

  /// Stored value ('system' / 'light' / 'dark') → ThemeMode.
  static ThemeMode modeFromSetting(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String settingFromMode(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
