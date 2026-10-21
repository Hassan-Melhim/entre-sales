// Loads assets/demo/demo_data.json into an in-memory database with the real
// loader, then checks the result against the inventory sheet.

import 'dart:convert';
import 'dart:io';

import 'package:entre_sales/core/assets.dart';
import 'package:entre_sales/data/sqlite/app_database.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_artist_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_data_admin_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_product_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_report_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_sales_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_session_repository.dart';
import 'package:entre_sales/domain/business_rules.dart';
import 'package:entre_sales/domain/models/date_range.dart';
import 'package:entre_sales/domain/models/product_filter.dart';
import 'package:entre_sales/domain/models/report_period.dart';
import 'package:entre_sales/domain/services/report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Map<String, dynamic> demo;
  late ReportService reports;
  final json = File(AppAssets.demoData).readAsStringSync();

  setUpAll(() async {
    sqfliteFfiInit();
    demo = jsonDecode(json) as Map<String, dynamic>;
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await SqliteDataAdminRepository(db).loadDemoData(json);
    reports = ReportService(SqliteReportRepository(db));
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
    final products = await SqliteProductRepository(db).products();
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
    final orders = await SqliteSalesRepository(db).orders();
    expect(orders.length, events.where((e) => e['t'] == 'sale').length);
    final refunds = (await db.rawQuery('SELECT COUNT(*) AS n FROM refunds')).first['n'] as int;
    expect(refunds, events.where((e) => e['t'] == 'refund').length);
    expect(orders.where((o) => o.discountName == 'Friends & Family'), isNotEmpty);
    expect(orders.where((o) => o.eventTagSource == 'auto'), isNotEmpty);
    expect(orders.where((o) => o.eventTagSource == 'manual'), isNotEmpty);
    expect((await SqliteSessionRepository(db).sessions()).length, (demo['sessions'] as List).length);
  });

  test('a known price: a 25 € poster is 20.66 € before VAT', () async {
    final poster = (await SqliteProductRepository(db).products(const ProductFilter(query: 'Risograph Poster'))).single;
    expect(poster.basePriceCents, 2066);
    expect(poster.priceWithTaxFor(poster.variants.first), 2500);
  });

  test('demo products with their own commission keep the artist rate unchanged', () async {
    final custom = [
      for (final p in (demo['products'] as List).cast<Map<String, dynamic>>())
        if (p['commission_override'] != null) p,
    ];
    expect(custom, isNotEmpty);
    final products = await SqliteProductRepository(db).products();
    for (final p in custom) {
      final product = products.firstWhere((x) => x.artistName == p['artist'] && x.name == p['name']);
      expect(product.commissionPercent, (p['commission_override'] as num).toDouble());
      final siblings = products.where((x) => x.artistId == product.artistId && !x.hasCustomCommission);
      for (final s in siblings) {
        expect(s.commissionPercent, s.artistCommissionPercent);
      }
    }
  });

  test('store-owned items pay no artist, café items have 0% VAT', () async {
    final artists = await SqliteArtistRepository(db).artists();
    final store = artists.firstWhere((a) => a.name == 'Entre Salas');
    final statement = await reports.statement(store, DateRange.days(DateTime(2026, 6, 1), DateTime(2026, 10, 18)));
    expect(statement.sales, isNotEmpty);
    expect(statement.payoutCents, 0);

    final cafe = (await SqliteProductRepository(db).products(const ProductFilter(query: 'Café')))
        .firstWhere((p) => p.name == 'Café');
    expect(cafe.taxPercent, 0);
  });

  test('monthly, quarterly and yearly reports have data', () async {
    final aug = await reports.salesReport(ReportPeriod.containing(PeriodKind.month, DateTime(2026, 8)));
    expect(aug.orderCount, greaterThan(100));
    expect(aug.profitCents, greaterThan(0));
    expect(aug.byGender.length, greaterThan(2));
    expect(aug.avgDaysToSell, isNotNull);

    final q3 = await reports.salesReport(ReportPeriod.containing(PeriodKind.quarter, DateTime(2026, 8)));
    expect(q3.orderCount, greaterThan(aug.orderCount));
    final year = await reports.salesReport(ReportPeriod.containing(PeriodKind.year, DateTime(2026)));
    expect(year.orderCount, greaterThan(q3.orderCount));
    expect(year.timeline.length, 12);
  });

  test('monthly payouts cover several artists', () async {
    final artists = await SqliteArtistRepository(db).artists();
    final statements = await reports.statements(artists, DateRange.month(2026, 9));
    expect(statements.where((s) => !s.isEmpty).length, greaterThan(5));
  });

  test('loading twice gives the same result', () async {
    final before = (await SqliteSalesRepository(db).orders()).length;
    await SqliteDataAdminRepository(db).loadDemoData(json);
    expect((await SqliteSalesRepository(db).orders()).length, before);
  });
}
