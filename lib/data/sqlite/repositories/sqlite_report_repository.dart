import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/dates.dart';
import '../../../domain/models/date_range.dart';
import '../../../domain/models/order_summary.dart';
import '../../../domain/models/refunded_item.dart';
import '../../../domain/models/sold_item.dart';
import '../../../domain/models/stock_item.dart';
import '../../../domain/repositories/report_repository.dart';
import '../db_values.dart';

class SqliteReportRepository implements ReportRepository {
  final Database _db;
  SqliteReportRepository(this._db);

  @override
  Future<List<OrderSummary>> orderSummaries(DateRange range) async {
    final rows = await _db.query('orders',
        where: 'created_at >= ? AND created_at < ?', whereArgs: [toDb(range.start), toDb(range.end)]);
    return [
      for (final r in rows)
        OrderSummary(
          id: r['id'] as int,
          createdAt: fromDb(r['created_at'] as String),
          paymentMethod: r['payment_method'] as String,
          discountCents: r['discount_cents'] as int,
          taxCents: r['tax_cents'] as int,
          totalCents: r['total_cents'] as int,
        ),
    ];
  }

  @override
  Future<List<SoldItem>> soldItems(DateRange range, {int? artistId}) async {
    final rows = await _db.rawQuery('''
      SELECT oi.*, o.created_at, a.name AS artist_name, a.gender, a.is_spain_resident
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN artists a ON a.id = oi.artist_id
      WHERE o.created_at >= ? AND o.created_at < ? ${artistId == null ? '' : 'AND oi.artist_id = ?'}''',
        [toDb(range.start), toDb(range.end), if (artistId != null) artistId]);
    return [
      for (final r in rows)
        SoldItem(
          orderId: r['order_id'] as int,
          soldAt: fromDb(r['created_at'] as String),
          artistId: r['artist_id'] as int,
          artistName: r['artist_name'] as String,
          artistGender: r['gender'] as String?,
          artistResident: boolFromDb(r['is_spain_resident']),
          productId: r['product_id'] as int?,
          productName: r['product_name'] as String,
          variantLabel: r['variant_label'] as String,
          categoryName: r['category_name'] as String,
          quantity: r['quantity'] as int,
          unitBaseCents: r['unit_base_cents'] as int,
          baseCents: r['base_cents'] as int,
          discountCents: r['discount_cents'] as int,
          taxCents: r['tax_cents'] as int,
          totalCents: r['total_cents'] as int,
          commissionPercent: doubleFromDb(r['commission_percent'])!,
          artistPayoutCents: r['artist_payout_cents'] as int,
          arrivalDate: r['arrival_date'] == null ? null : fromDb(r['arrival_date'] as String),
        ),
    ];
  }

  @override
  Future<List<RefundedItem>> refundedItems(DateRange range, {int? artistId}) async {
    final rows = await _db.rawQuery('''
      SELECT r.quantity, r.base_cents, r.tax_cents, r.total_cents, r.artist_payout_cents, r.created_at,
             oi.order_id, oi.artist_id, oi.product_id, oi.product_name, oi.variant_label, oi.category_name,
             oi.unit_base_cents, oi.commission_percent,
             a.name AS artist_name, a.gender, a.is_spain_resident
      FROM refunds r
      JOIN order_items oi ON oi.id = r.order_item_id
      JOIN artists a ON a.id = oi.artist_id
      WHERE r.created_at >= ? AND r.created_at < ? ${artistId == null ? '' : 'AND oi.artist_id = ?'}''',
        [toDb(range.start), toDb(range.end), if (artistId != null) artistId]);
    return [
      for (final r in rows)
        RefundedItem(
          orderId: r['order_id'] as int,
          refundedAt: fromDb(r['created_at'] as String),
          artistId: r['artist_id'] as int,
          artistName: r['artist_name'] as String,
          artistGender: r['gender'] as String?,
          artistResident: boolFromDb(r['is_spain_resident']),
          productId: r['product_id'] as int?,
          productName: r['product_name'] as String,
          variantLabel: r['variant_label'] as String,
          categoryName: r['category_name'] as String,
          quantity: r['quantity'] as int,
          unitBaseCents: r['unit_base_cents'] as int,
          baseCents: r['base_cents'] as int,
          taxCents: r['tax_cents'] as int,
          totalCents: r['total_cents'] as int,
          commissionPercent: doubleFromDb(r['commission_percent'])!,
          artistPayoutCents: r['artist_payout_cents'] as int,
        ),
    ];
  }

  @override
  Future<List<StockItem>> stockItems() async {
    final rows = await _db.rawQuery('''
      SELECT p.id AS product_id, p.name AS product_name, a.name AS artist_name, c.name AS category_name,
             v.quantity, v.date_of_arrival
      FROM variants v
      JOIN products p ON p.id = v.product_id
      JOIN artists a ON a.id = p.artist_id
      JOIN categories c ON c.id = p.category_id
      WHERE v.quantity > 0''');
    return [
      for (final r in rows)
        StockItem(
          productId: r['product_id'] as int,
          productName: r['product_name'] as String,
          artistName: r['artist_name'] as String,
          categoryName: r['category_name'] as String,
          quantity: r['quantity'] as int,
          arrival: fromDb(r['date_of_arrival'] as String),
        ),
    ];
  }
}
