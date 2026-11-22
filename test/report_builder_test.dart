// The Reports figures, worked through by hand.

import 'package:entre_sales/domain/business_rules.dart';
import 'package:entre_sales/domain/models/order_summary.dart';
import 'package:entre_sales/domain/models/report_period.dart';
import 'package:entre_sales/domain/models/sold_item.dart';
import 'package:entre_sales/domain/models/stock_item.dart';
import 'package:entre_sales/domain/services/sales_report_builder.dart';
import 'package:flutter_test/flutter_test.dart';

SoldItem item(int order, int artistId, String artist, bool resident,
        {required int base, required int discount, required int tax, required int payout}) =>
    SoldItem(
      orderId: order,
      soldAt: DateTime(2026, 11, 10, 12),
      artistId: artistId,
      artistName: artist,
      artistGender: null,
      artistResident: resident,
      productId: order,
      productName: 'Product $order',
      variantLabel: 'Standard',
      categoryName: 'Ceramics',
      quantity: 1,
      unitBaseCents: base + discount,
      baseCents: base,
      discountCents: discount,
      taxCents: tax,
      totalCents: base + tax,
      commissionPercent: 35,
      artistPayoutCents: payout,
      arrivalDate: null,
    );

void main() {
  final onTop = BusinessRules.residentTaxAddedOnTop && BusinessRules.spainResidentArtistTaxPercent == 10;

  // Sale 1: 100 € piece, 10% discount, 21% VAT, 35% commission, resident artist, card, during a workshop.
  //   customer pays 90 + 18.90 = 108.90; artist share 65; resident tax 6.50; store keeps 18.50.
  // Sale 2: 50 € piece, 21% VAT, 40% commission, non-resident, cash.
  //   customer pays 60.50; VAT 10.50; artist 30; store keeps 20.
  final report = SalesReportBuilder.build(
    period: ReportPeriod.containing(PeriodKind.month, DateTime(2026, 11)),
    orders: [
      OrderSummary(
          id: 1, createdAt: DateTime(2026, 11, 10, 12), paymentMethod: 'Card',
          discountCents: 1000, taxCents: 1890, totalCents: 10890, sessionId: 7),
      OrderSummary(
          id: 2, createdAt: DateTime(2026, 11, 11, 17), paymentMethod: 'Cash',
          discountCents: 0, taxCents: 1050, totalCents: 6050),
    ],
    sold: [
      item(1, 1, 'Ana', true, base: 9000, discount: 1000, tax: 1890, payout: 6500),
      item(2, 2, 'Ben', false, base: 5000, discount: 0, tax: 1050, payout: 3000),
    ],
    refunds: const [],
    stock: [
      StockItem(
        productId: 9, productName: 'Vase', artistName: 'Ana', categoryName: 'Ceramics', quantity: 2,
        arrival: DateTime(2026, 10, 1), artistId: 1, artistResident: true,
        unitBaseCents: 10000, taxPercent: 21, commissionPercent: 35,
      ),
    ],
    now: DateTime(2026, 11, 22),
  );

  test('headline figures add up: sales = profit + payouts + taxes', () {
    expect(report.revenueCents, 16940);
    expect(report.vatCents, 2940);
    expect(report.artistResidentTaxCents, 650);
    expect(report.taxesCents, 3590);
    expect(report.artistPayoutCents, 9500);
    expect(report.profitCents, 3850);
    expect(report.profitCents + report.artistPayoutCents + report.taxesCents, report.revenueCents);
    expect(report.marginPercent!.toStringAsFixed(1), '27.5');
    expect(report.orderCount, 2);
    expect(report.unitsSold, 2);
    expect(report.averageSaleCents, 8470);
    expect(report.itemsPerSale, 1);
  }, skip: onTop ? false : 'written for the resident tax added on top at 10%');

  test('store profit per artist', () {
    final byProfit = report.byArtistProfit;
    expect(byProfit.map((b) => b.label), ['Ben', 'Ana']);
    expect(byProfit.map((b) => b.profitCents), [2000, 1850]);
  }, skip: onTop ? false : 'written for the resident tax added on top at 10%');

  test('cash and card, workshops', () {
    expect(report.payments.map((p) => (p.method, p.orders, p.revenueCents)), [('Card', 1, 10890), ('Cash', 1, 6050)]);
    expect(report.sessions.sessionCount, 1);
    expect(report.sessions.sessionRevenueCents, 10890);
    expect(report.sessions.otherOrders, 1);
    expect(report.sessions.otherAverageCents, 6050);
  });

  test('stock on the shelf at full price', () {
    final v = report.stockValue!;
    expect(v.units, 2);
    expect(v.shelfCents, 24200);
    expect(v.taxesCents, 5500); // 42 VAT + 13 resident tax
    expect(v.artistPayoutCents, 13000);
    expect(v.storeProfitCents, 5700);
    expect(v.byArtist.single.artist, 'Ana');
  }, skip: onTop ? false : 'written for the resident tax added on top at 10%');

  test('no stock value before the database update', () {
    final r = SalesReportBuilder.stockValue([
      StockItem(
          productId: 1, productName: 'x', artistName: 'y', categoryName: 'z', quantity: 1,
          arrival: DateTime(2026)),
    ]);
    expect(r, isNull);
  });
}
