// Runs the real SQL against an in-memory SQLite database (via
// sqflite_common_ffi), so `flutter test` on a computer checks the whole
// data layer: schema, sales, stock checks, refunds, settlements, reports.

import 'package:entre_sales/config/business_rules.dart';
import 'package:entre_sales/core/exceptions.dart';
import 'package:entre_sales/core/pricing.dart';
import 'package:entre_sales/data/database.dart';
import 'package:entre_sales/data/repositories/calendar_repository.dart';
import 'package:entre_sales/data/repositories/discount_repository.dart';
import 'package:entre_sales/data/repositories/inventory_repository.dart';
import 'package:entre_sales/data/repositories/report_repository.dart';
import 'package:entre_sales/data/repositories/sales_repository.dart';
import 'package:entre_sales/models/artist.dart';
import 'package:entre_sales/models/cart_line.dart';
import 'package:entre_sales/models/date_range.dart';
import 'package:entre_sales/models/order_status.dart';
import 'package:entre_sales/models/product.dart';
import 'package:entre_sales/models/variant.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late InventoryRepository inventory;
  late SalesRepository sales;
  late ReportRepository reports;
  late CalendarRepository calendar;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    inventory = InventoryRepository(db);
    sales = SalesRepository(db);
    reports = ReportRepository(db);
    calendar = CalendarRepository(db);
  });

  tearDown(() => db.close());

  /// A Spain-resident artist with a poster in two sizes (100 € before tax).
  Future<(Artist, Product)> seedPoster({int a3 = 1, int a2 = 2}) async {
    final artistId = await inventory.saveArtist(const Artist(name: 'Ana', isSpainResident: true));
    final artist = (await inventory.artist(artistId))!;
    final posters = (await inventory.categories()).firstWhere((c) => c.name == 'Posters');
    final arrival = DateTime.now().subtract(const Duration(days: 10));
    final productId = await inventory.saveProduct(
      name: 'Sunset print',
      artistId: artistId,
      categoryId: posters.id!,
      basePriceCents: 10000,
      perVariantPricing: false,
      taxPercentOverride: null,
      variants: [
        Variant(attributes: const {'Size': 'A3'}, quantity: a3, dateOfArrival: arrival),
        Variant(attributes: const {'Size': 'A2'}, quantity: a2, dateOfArrival: arrival),
      ],
    );
    return (artist, (await inventory.product(productId))!);
  }

  test('fresh database has the seed categories and discount', () async {
    final cats = await inventory.categories();
    expect(cats.map((c) => c.name), containsAll(['Clothes', 'Books', 'Posters', 'Ceramics']));
    expect(cats.firstWhere((c) => c.name == 'Books').taxPercent, 4);
    expect(cats.firstWhere((c) => c.name == 'Clothes').attributes.single.name, 'Size');

    final discounts = await DiscountRepository(db).discounts();
    expect(discounts.single.name, 'Friends & Family');
    expect(discounts.single.percent, 5);
  });

  test('a sale records tax, discount, payout and lowers stock', () async {
    final (_, poster) = await seedPoster();
    final a3 = poster.variants.firstWhere((v) => v.label == 'A3');
    final discount = (await DiscountRepository(db).discounts()).single;

    final orderId = await sales.checkout(
      lines: [CartLine(product: poster, variant: a3, quantity: 1)],
      paymentMethod: 'Card',
      discount: discount,
    );
    final order = (await sales.order(orderId))!;

    expect(order.subtotalCents, 9500); // 100 € − 5%
    expect(order.taxCents, 1995); // 21%
    expect(order.totalCents, 11495);
    expect(order.items.single.artistPayoutCents, BusinessRules.discountReducesArtistPayout ? 6175 : 6500);

    final after = (await inventory.product(poster.id!))!;
    expect(after.variants.firstWhere((v) => v.label == 'A3').quantity, 0);
  });

  test('cannot sell more than is in stock', () async {
    final (_, poster) = await seedPoster(a3: 1);
    final a3 = poster.variants.firstWhere((v) => v.label == 'A3');
    await expectLater(
      sales.checkout(lines: [CartLine(product: poster, variant: a3, quantity: 2)], paymentMethod: 'Cash'),
      throwsA(isA<InsufficientStockException>()),
    );
    // Nothing was recorded and stock is unchanged.
    expect(await sales.orders(), isEmpty);
    expect((await inventory.product(poster.id!))!.variants.firstWhere((v) => v.label == 'A3').quantity, 1);
  });

  test('out-of-stock products are listed last', () async {
    final (artist, _) = await seedPoster();
    final clothes = (await inventory.categories()).firstWhere((c) => c.name == 'Clothes');
    await inventory.saveProduct(
      name: 'Aardvark shirt', // alphabetically first
      artistId: artist.id!,
      categoryId: clothes.id!,
      basePriceCents: 3000,
      perVariantPricing: false,
      taxPercentOverride: null,
      variants: [Variant(attributes: const {'Size': 'M'}, quantity: 0, dateOfArrival: DateTime.now())],
    );
    final list = await inventory.products();
    expect(list.map((p) => p.name).toList(), ['Sunset print', 'Aardvark shirt']);
    expect(list.last.isOutOfStock, isTrue);
  });

  test('refund returns stock and is deducted from the artist settlement', () async {
    final (artist, poster) = await seedPoster();
    final a2 = poster.variants.firstWhere((v) => v.label == 'A2');
    final orderId = await sales.checkout(
      lines: [CartLine(product: poster, variant: a2, quantity: 2)],
      paymentMethod: 'Cash',
    );
    final item = (await sales.order(orderId))!.items.single;

    await sales.refund(orderId, {item.id: 1});
    var order = (await sales.order(orderId))!;
    expect(order.status, OrderStatus.partiallyRefunded);
    expect((await inventory.product(poster.id!))!.variants.firstWhere((v) => v.label == 'A2').quantity, 1);

    final period = DateRange.biweeklyContaining(DateTime.now());
    final statement = await reports.artistStatement(artist, period);
    expect(statement.payoutCents, 6500); // 2 × 65 € sold − 1 × 65 € refunded
    expect(statement.netPayoutCents, Pricing.artistNetPayout(payoutCents: 6500, spainResident: true));

    await sales.refund(orderId, {item.id: 1});
    order = (await sales.order(orderId))!;
    expect(order.status, OrderStatus.refunded);
  });

  test('monthly report adds up', () async {
    final (_, poster) = await seedPoster();
    final a2 = poster.variants.firstWhere((v) => v.label == 'A2');
    await sales.checkout(lines: [CartLine(product: poster, variant: a2, quantity: 1)], paymentMethod: 'Card');

    final now = DateTime.now();
    final r = await reports.monthly(DateRange.month(now.year, now.month));
    expect(r.orderCount, 1);
    expect(r.unitsSold, 1);
    expect(r.revenueCents, 12100);
    expect(r.artistPayoutCents, 6500);
    expect(
      r.profitCents,
      Pricing.storeProfit(customerPaidCents: 12100, artistPayoutCents: 6500, artistResidentTaxAddedCents: 650),
    );
    expect(r.byCategory.single.label, 'Posters');
    expect(r.avgDaysToSell, closeTo(10, 0.1));
  });

  test('sales during a workshop are tagged automatically', () async {
    final (_, poster) = await seedPoster();
    final now = DateTime.now();
    await calendar.addManualSession(
        'Ceramics workshop', now.subtract(const Duration(hours: 1)), now.add(const Duration(hours: 1)));
    final a2 = poster.variants.firstWhere((v) => v.label == 'A2');
    final orderId =
        await sales.checkout(lines: [CartLine(product: poster, variant: a2, quantity: 1)], paymentMethod: 'Cash');
    expect((await sales.order(orderId))!.calendarEventTitle, 'Ceramics workshop');
  });
}
