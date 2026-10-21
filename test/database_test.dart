// Runs the real SQL against an in-memory SQLite database (via
// sqflite_common_ffi), so `flutter test` on a computer checks the whole
// data layer: schema, sales, stock checks, refunds, statements, reports.

import 'dart:io';

import 'package:entre_sales/core/dates.dart';
import 'package:entre_sales/data/sqlite/app_database.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_artist_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_category_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_discount_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_product_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_report_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_sales_repository.dart';
import 'package:entre_sales/data/sqlite/repositories/sqlite_session_repository.dart';
import 'package:entre_sales/domain/business_rules.dart';
import 'package:entre_sales/domain/exceptions.dart';
import 'package:entre_sales/domain/models/artist.dart';
import 'package:entre_sales/domain/models/calendar_session.dart';
import 'package:entre_sales/domain/models/cart_line.dart';
import 'package:entre_sales/domain/models/date_range.dart';
import 'package:entre_sales/domain/models/order_status.dart';
import 'package:entre_sales/domain/models/product.dart';
import 'package:entre_sales/domain/models/report_period.dart';
import 'package:entre_sales/domain/models/variant.dart';
import 'package:entre_sales/domain/pricing.dart';
import 'package:entre_sales/domain/services/report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SqliteArtistRepository artists;
  late SqliteCategoryRepository categories;
  late SqliteProductRepository products;
  late SqliteSalesRepository sales;
  late SqliteSessionRepository sessions;
  late ReportService reports;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    artists = SqliteArtistRepository(db);
    categories = SqliteCategoryRepository(db);
    products = SqliteProductRepository(db);
    sales = SqliteSalesRepository(db);
    sessions = SqliteSessionRepository(db);
    reports = ReportService(SqliteReportRepository(db));
  });

  tearDown(() => db.close());

  /// A Spain-resident artist with a poster in two sizes (100 € before tax).
  Future<(Artist, Product)> seedPoster({int a3 = 1, int a2 = 2, double? artistCommission, double? productCommission}) async {
    final artistId =
        await artists.save(Artist(name: 'Ana', isSpainResident: true, commissionPercent: artistCommission));
    final artist = (await artists.artist(artistId))!;
    final posters = (await categories.categories()).firstWhere((c) => c.name == 'Prints & Posters');
    final arrival = DateTime.now().subtract(const Duration(days: 10));
    final productId = await products.save(
      name: 'Sunset print',
      artistId: artistId,
      categoryId: posters.id!,
      basePriceCents: 10000,
      perVariantPricing: false,
      taxPercentOverride: null,
      commissionPercentOverride: productCommission,
      variants: [
        Variant(attributes: const {'Size': 'A3'}, quantity: a3, dateOfArrival: arrival),
        Variant(attributes: const {'Size': 'A2'}, quantity: a2, dateOfArrival: arrival),
      ],
    );
    return (artist, (await products.product(productId))!);
  }

  Variant size(Product p, String label) => p.variants.firstWhere((v) => v.label == label);
  DateRange thisMonth() => DateRange.month(DateTime.now().year, DateTime.now().month);

  test('fresh database has the seed categories and discount', () async {
    final cats = await categories.categories();
    expect(cats.map((c) => c.name), containsAll(seedCategories.map((c) => c.name)));
    expect(cats.firstWhere((c) => c.name == 'Books & Zines').taxPercent, 4);
    expect(cats.firstWhere((c) => c.name == 'Food & Drink').taxPercent, 0);
    expect(cats.firstWhere((c) => c.name == 'Clothing').attributes.first.name, 'Size');

    final discounts = await SqliteDiscountRepository(db).discounts();
    expect(discounts.single.name, 'Friends & Family');
    expect(discounts.single.percent, 5);
  });

  test('a sale records tax, discount, payout and lowers stock', () async {
    final (_, poster) = await seedPoster();
    final discount = (await SqliteDiscountRepository(db).discounts()).single;

    final orderId = await sales.checkout(
      lines: [CartLine(product: poster, variant: size(poster, 'A3'), quantity: 1)],
      paymentMethod: 'Card',
      discount: discount,
    );
    final order = (await sales.order(orderId))!;

    expect(order.subtotalCents, 9500); // 100 € − 5%
    expect(order.taxCents, 1995); // 21%
    expect(order.totalCents, 11495);
    expect(order.items.single.artistPayoutCents, BusinessRules.discountReducesArtistPayout ? 6175 : 6500);
    expect(size((await products.product(poster.id!))!, 'A3').quantity, 0);
  });

  test('cannot sell more than is in stock', () async {
    final (_, poster) = await seedPoster(a3: 1);
    await expectLater(
      sales.checkout(lines: [CartLine(product: poster, variant: size(poster, 'A3'), quantity: 2)], paymentMethod: 'Cash'),
      throwsA(isA<InsufficientStockException>()),
    );
    // Nothing was recorded and stock is unchanged.
    expect(await sales.orders(), isEmpty);
    expect(size((await products.product(poster.id!))!, 'A3').quantity, 1);
  });

  test('out-of-stock products are listed last', () async {
    final (artist, _) = await seedPoster();
    final clothing = (await categories.categories()).firstWhere((c) => c.name == 'Clothing');
    await products.save(
      name: 'Aardvark shirt', // alphabetically first
      artistId: artist.id!,
      categoryId: clothing.id!,
      basePriceCents: 3000,
      perVariantPricing: false,
      taxPercentOverride: null,
      commissionPercentOverride: null,
      variants: [Variant(attributes: const {'Size': 'M'}, quantity: 0, dateOfArrival: DateTime.now())],
    );
    final list = await products.products();
    expect(list.map((p) => p.name).toList(), ['Sunset print', 'Aardvark shirt']);
    expect(list.last.isOutOfStock, isTrue);
  });

  group('Commission', () {
    test('store default when nothing is set', () async {
      final (_, poster) = await seedPoster();
      expect(poster.commissionPercent, BusinessRules.defaultCommissionPercent);
      expect(poster.hasCustomCommission, isFalse);
    });

    test('artist rate applies to their products', () async {
      final (_, poster) = await seedPoster(artistCommission: 40);
      expect(poster.commissionPercent, 40);
    });

    test('product rate wins over the artist rate, which stays unchanged', () async {
      final (artist, poster) = await seedPoster(artistCommission: 40, productCommission: 20);
      expect(poster.commissionPercent, 20);
      expect((await artists.artist(artist.id!))!.commissionPercent, 40);

      final orderId = await sales.checkout(
          lines: [CartLine(product: poster, variant: size(poster, 'A2'), quantity: 1)], paymentMethod: 'Card');
      final item = (await sales.order(orderId))!.items.single;
      expect(item.commissionPercent, 20);
      expect(item.artistPayoutCents, 8000); // 100 € − 20%
    });

    test('changing a rate later does not change past sales', () async {
      final (_, poster) = await seedPoster();
      final orderId = await sales.checkout(
          lines: [CartLine(product: poster, variant: size(poster, 'A2'), quantity: 1)], paymentMethod: 'Card');

      await products.setCommissionOverride(poster.id!, 50);
      expect((await products.product(poster.id!))!.commissionPercent, 50);
      expect((await sales.order(orderId))!.items.single.artistPayoutCents, 6500);

      await products.setCommissionOverride(poster.id!, null);
      expect((await products.product(poster.id!))!.hasCustomCommission, isFalse);
    });
  });

  test('refund returns stock and is deducted from the monthly statement', () async {
    final (artist, poster) = await seedPoster();
    final orderId = await sales.checkout(
      lines: [CartLine(product: poster, variant: size(poster, 'A2'), quantity: 2)],
      paymentMethod: 'Cash',
    );
    final item = (await sales.order(orderId))!.items.single;

    await sales.refund(orderId, {item.id: 1});
    var order = (await sales.order(orderId))!;
    expect(order.status, OrderStatus.partiallyRefunded);
    expect(size((await products.product(poster.id!))!, 'A2').quantity, 1);

    final statement = await reports.statement(artist, thisMonth());
    expect(statement.payoutCents, 6500); // 2 × 65 € sold − 1 × 65 € refunded
    expect(statement.netPayoutCents, Pricing.artistNetPayout(payoutCents: 6500, spainResident: true));

    await sales.refund(orderId, {item.id: 1});
    order = (await sales.order(orderId))!;
    expect(order.status, OrderStatus.refunded);
  });

  test('a single-day statement includes that whole day', () async {
    final (artist, poster) = await seedPoster();
    await sales.checkout(
        lines: [CartLine(product: poster, variant: size(poster, 'A2'), quantity: 1)], paymentMethod: 'Card');
    final today = await reports.statement(artist, DateRange.day(DateTime.now()));
    expect(today.soldUnits, 1);
    final yesterday =
        await reports.statement(artist, DateRange.day(DateTime.now().subtract(const Duration(days: 1))));
    expect(yesterday.isEmpty, isTrue);
  });

  test('sales report adds up for every kind of period', () async {
    final (_, poster) = await seedPoster();
    await sales.checkout(
        lines: [CartLine(product: poster, variant: size(poster, 'A2'), quantity: 1)], paymentMethod: 'Card');

    final now = DateTime.now();
    for (final kind in [PeriodKind.day, PeriodKind.month, PeriodKind.quarter, PeriodKind.year]) {
      final r = await reports.salesReport(ReportPeriod.containing(kind, now));
      expect(r.orderCount, 1, reason: '$kind');
      expect(r.revenueCents, 12100, reason: '$kind');
      expect(r.timeline.fold<int>(0, (s, p) => s + p.revenueCents), 12100, reason: '$kind timeline');
    }

    final r = await reports.salesReport(ReportPeriod.containing(PeriodKind.month, now));
    expect(r.unitsSold, 1);
    expect(r.artistPayoutCents, 6500);
    expect(
      r.profitCents,
      Pricing.storeProfit(customerPaidCents: 12100, artistPayoutCents: 6500, artistResidentTaxAddedCents: 650),
    );
    expect(r.byCategory.single.label, 'Prints & Posters');
    expect(r.avgDaysToSell, closeTo(10, 0.1));
  });

  test('sales during a workshop are tagged automatically', () async {
    final (_, poster) = await seedPoster();
    final now = DateTime.now();
    await sessions.add(CalendarSession(
        title: 'Ceramics workshop',
        start: now.subtract(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 1))));
    final orderId = await sales.checkout(
        lines: [CartLine(product: poster, variant: size(poster, 'A2'), quantity: 1)], paymentMethod: 'Cash');
    expect((await sales.order(orderId))!.calendarEventTitle, 'Ceramics workshop');
  });

  test('a version 1 database is upgraded without losing data', () async {
    final dir = await Directory.systemTemp.createTemp('entre_sales_test');
    final path = '${dir.path}/v1.db';
    try {
      // Build a version 1 database: today's schema without the v2 column.
      var old = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
      await old.execute('ALTER TABLE products DROP COLUMN commission_percent_override');
      final artistId = await old.insert('artists', {'name': 'Old artist', 'is_spain_resident': 0, 'created_at': toDb(DateTime.now())});
      final cat = (await old.query('categories', limit: 1)).first['id'];
      await old.insert('products', {
        'name': 'Old product',
        'artist_id': artistId,
        'category_id': cat,
        'base_price_cents': 1000,
        'per_variant_pricing': 0,
        'created_at': toDb(DateTime.now()),
      });
      await old.setVersion(1);
      await old.close();

      final upgraded = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
      expect(await upgraded.getVersion(), AppDatabase.schemaVersion);
      final p = (await SqliteProductRepository(upgraded).products()).single;
      expect(p.name, 'Old product');
      expect(p.hasCustomCommission, isFalse);
      await SqliteProductRepository(upgraded).setCommissionOverride(p.id!, 25);
      expect((await SqliteProductRepository(upgraded).product(p.id!))!.commissionPercent, 25);
      await upgraded.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
