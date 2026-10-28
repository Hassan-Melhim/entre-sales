// Reads rows exactly as the Supabase database returns them (captured from
// the real migrations by supabase/tests/test_migrations.py) and checks they
// turn into the right models, and that reports add up.

import 'dart:convert';
import 'dart:io';

import 'package:entre_sales/data/supabase/supabase_mappers.dart';
import 'package:entre_sales/data/supabase/supabase_values.dart';
import 'package:entre_sales/domain/models/date_range.dart';
import 'package:entre_sales/domain/models/order_status.dart';
import 'package:entre_sales/domain/models/order_summary.dart';
import 'package:entre_sales/domain/models/refunded_item.dart';
import 'package:entre_sales/domain/models/report_period.dart';
import 'package:entre_sales/domain/models/sold_item.dart';
import 'package:entre_sales/domain/models/stock_item.dart';
import 'package:entre_sales/domain/repositories/report_repository.dart';
import 'package:entre_sales/domain/services/report_service.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, dynamic> fx =
    jsonDecode(File('test/fixtures/supabase_rows.json').readAsStringSync()) as Map<String, dynamic>;

List<DbRow> rows(String table) => asRows(fx[table]);

/// Report facts straight from the captured rows.
class _FixtureReports implements ReportRepository {
  @override
  Future<List<OrderSummary>> orderSummaries(DateRange range) async =>
      rows('report_order_summaries').map(SupabaseMappers.orderSummary).toList();
  @override
  Future<List<SoldItem>> soldItems(DateRange range, {int? artistId}) async => rows('report_sold_items')
      .map(SupabaseMappers.soldItem)
      .where((i) => artistId == null || i.artistId == artistId)
      .toList();
  @override
  Future<List<RefundedItem>> refundedItems(DateRange range, {int? artistId}) async => rows('report_refunded_items')
      .map(SupabaseMappers.refundedItem)
      .where((i) => artistId == null || i.artistId == artistId)
      .toList();
  @override
  Future<List<StockItem>> stockItems() async => rows('report_stock_items').map(SupabaseMappers.stockItem).toList();
}

void main() {
  test('values: times come back in local time, days as plain dates', () {
    final t = parseMoment('2026-10-28T13:15:02.851638+00:00');
    expect(t.isUtc, isFalse);
    expect(t.toUtc(), DateTime.utc(2026, 10, 28, 13, 15, 2, 851, 638));
    expect(momentToDb(t), '2026-10-28T13:15:02.851638Z');
    expect(parseDay('2026-10-01'), DateTime(2026, 10, 1));
    expect(dayToDb(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('every table maps to models', () {
    expect(rows('artists').map(SupabaseMappers.artist).first.commissionPercent, 40);
    final cats = rows('categories').map(SupabaseMappers.category).toList();
    expect(cats.length, 15);
    final clothing = cats.firstWhere((c) => c.name == 'Clothing');
    expect(clothing.attributes.map((a) => a.name), ['Size', 'Style']);
    expect(clothing.attributes.first.options, contains('XS/S'));
    expect(rows('discounts').map(SupabaseMappers.discount).first.percent, 5);
    expect(rows('calendar_events').map(SupabaseMappers.session).first.title, 'Ceramics workshop');
  });

  test('product with its variants, field order and commission', () {
    final p = rows('product_rows').map(SupabaseMappers.product).firstWhere((p) => p.name == 'Sunset print');
    expect(p.variants.first.attributes.keys, ['Design', 'Size']); // order as typed
    expect(p.variants.first.label, 'Sun · A3');
    expect(p.commissionPercent, 20); // product's own rate wins over the artist's 40%
    expect(p.artistCommissionPercent, 40);
    expect(p.taxPercent, 21);
  });

  test('order with its lines', () {
    final o = rows('order_rows').map(SupabaseMappers.order).first;
    expect(o.totalCents, 11495);
    expect(o.discountName, 'Friends & Family');
    expect(o.status, OrderStatus.completed);
    expect(o.items.single.variantLabel, 'Sun · A3');
    expect(o.items.single.artistPayoutCents, 6500);
  });

  test('a report over the captured sales adds up', () async {
    final orders = rows('report_order_summaries');
    final refunds = rows('report_refunded_items');
    final r = await ReportService(_FixtureReports())
        .salesReport(ReportPeriod.containing(PeriodKind.year, DateTime.now()));
    expect(r.orderCount, orders.length);
    expect(
      r.revenueCents,
      orders.fold<int>(0, (s, o) => s + asInt(o['total_cents'])) -
          refunds.fold<int>(0, (s, x) => s + asInt(x['total_cents'])),
    );
  });
}
