// Replaces the sample test that `flutter create` generates (it referenced a
// `MyApp` class that does not exist in this project).

import 'package:entre_sales/core/money.dart';
import 'package:entre_sales/ui/common.dart';
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

  testWidgets('out-of-stock tag renders its text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Tag('Out of stock', color: Colors.red, icon: Icons.warning_amber_rounded)),
    ));
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
