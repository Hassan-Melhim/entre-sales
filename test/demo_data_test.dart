// Loads assets/demo/demo_data.json into an in-memory database with the real
// loader, then checks the result against the inventory sheet.

import 'dart:convert';
import 'dart:io';

import 'package:entre_sales/config/business_rules.dart';
import 'package:entre_sales/data/database.dart';
import 'package:entre_sales/data/repositories/calendar_repository.dart';
import 'package:entre_sales/data/repositories/inventory_repository.dart';
import 'package:entre_sales/data/repositories/report_repository.dart';
import 'package:entre_sales/data/repositories/sales_repository.dart';
import 'package:entre_sales/models/date_range.dart';
import 'package:entre_sales/services/demo_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Map<String, dynamic> demo;
  final json = File(DemoDataService.assetPath).readAsStringSync();

  setUpAll(() async {
    sqfliteFfiInit();
    demo = jsonDecode(json) as Map<String, dynamic>;
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await DemoDataService.load(db, json);
  });

  tearDownAll(() => db.close());

  test('default categories match the demo categories', () {
    final demoCats = (demo['categories'] as List).map((c) => c['name']).toList();
    expect(seedCategories.map((c) => c.name).toList(), demoCats);
    for (final c in demo['categories'] as List) {
      final seed = seedCategories.firstWhere((s) => s.name == c['name']);
      expect(seed.taxPercent, (c['tax'] as num).toDouble(), reason: c['name'] as String);
      expect(seed.attributes.keys.toList(), (c['attributes'] as List).map((a) => a['name']).toList());
    }
  });

  test('every variant ends at the quantity from the inventory sheet', () async {
    final products = await InventoryRepository(db).products();
    final byKey = {for (final p in products) '${p.artistName}|${p.name}': p};
    var checked = 0;
    for (final p in (demo['products'] as List).cast<Map<String, dynamic>>()) {
      final product = byKey['${p['artist']}|${p['name']}']!;
      final variants = (p['variants'] as List).cast<Map<String, dynamic>>();
      expect(product.variants.length, variants.length);
      for (var i = 0; i < variants.length; i++) {
        expect(product.variants[i].quantity, variants[i]['final'], reason: '${p['name']} ${variants[i]['attrs']}');
        checked++;
      }
    }
    expect(checked, greaterThan(400));
  });

  test('sales, refunds and sessions were all recorded', () async {
    final events = (demo['events'] as List).cast<Map<String, dynamic>>();
    final orders = await SalesRepository(db).orders();
    expect(orders.length, events.where((e) => e['t'] == 'sale').length);
    final refunds = (await db.rawQuery('SELECT COUNT(*) AS n FROM refunds')).first['n'] as int;
    expect(refunds, events.where((e) => e['t'] == 'refund').length);
    expect(orders.where((o) => o.discountName == 'Friends & Family'), isNotEmpty);
    expect(orders.where((o) => o.eventTagSource == 'auto'), isNotEmpty);
    expect(orders.where((o) => o.eventTagSource == 'manual'), isNotEmpty);
    expect((await CalendarRepository(db).sessions()).length, (demo['sessions'] as List).length);
  });

  test('a known price: a 25 € poster is 20.66 € before VAT', () async {
    final poster = (await InventoryRepository(db).products(query: 'Risograph Poster')).single;
    expect(poster.basePriceCents, 2066);
    expect(poster.priceWithTaxFor(poster.variants.first), 2500);
  });

  test('store-owned items pay no artist, café items have 0% VAT', () async {
    final reports = ReportRepository(db);
    final artists = await InventoryRepository(db).artists();
    final store = artists.firstWhere((a) => a.name == 'Entre Salas');
    final range = DateRange(DateTime(2026, 6, 1), DateTime(2026, 10, 19));
    final statement = await reports.artistStatement(store, range);
    expect(statement.sales, isNotEmpty);
    expect(statement.payoutCents, 0);

    final cafe = (await InventoryRepository(db).products(query: 'Café')).firstWhere((p) => p.name == 'Café');
    expect(cafe.taxPercent, 0);
  });

  test('monthly report and biweekly payouts have data', () async {
    final reports = ReportRepository(db);
    final aug = await reports.monthly(DateRange.month(2026, 8));
    expect(aug.orderCount, greaterThan(100));
    expect(aug.profitCents, greaterThan(0));
    expect(aug.byGender.length, greaterThan(2));
    expect(aug.avgDaysToSell, isNotNull);

    final artists = await InventoryRepository(db).artists();
    final statements = await reports.allStatements(artists, DateRange.biweeklyContaining(DateTime(2026, 9, 10)));
    expect(statements.length, greaterThan(5));
  });

  test('loading twice gives the same result', () async {
    final before = (await SalesRepository(db).orders()).length;
    await DemoDataService.load(db, json);
    expect((await SalesRepository(db).orders()).length, before);
  });
}
