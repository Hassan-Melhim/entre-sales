import 'package:entre_sales/core/money.dart';
import 'package:entre_sales/presentation/theme/app_theme.dart';
import 'package:entre_sales/presentation/widgets/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses euro amounts typed with a comma or a dot', () {
    expect(parseEurosToCents('12,50'), 1250);
    expect(parseEurosToCents('12.5'), 1250);
    expect(parseEurosToCents('abc'), isNull);
    expect(parsePercent('21'), 21);
    expect(parsePercent('150'), isNull);
  });

  test('theme setting round-trips', () {
    for (final m in ThemeMode.values) {
      expect(AppTheme.modeFromSetting(AppTheme.settingFromMode(m)), m);
    }
    expect(AppTheme.modeFromSetting(null), ThemeMode.system);
  });

  for (final dark in [false, true]) {
    testWidgets('tag renders in ${dark ? 'dark' : 'light'} mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: Tag('Out of stock', color: Colors.red, icon: Icons.warning_amber_rounded)),
      ));
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  }
}
