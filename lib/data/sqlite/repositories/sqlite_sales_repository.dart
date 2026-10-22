import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/dates.dart';
import '../../../domain/exceptions.dart';
import '../../../domain/models/cart_line.dart';
import '../../../domain/models/discount.dart';
import '../../../domain/models/line_amounts.dart';
import '../../../domain/models/order_filter.dart';
import '../../../domain/models/order_item.dart';
import '../../../domain/models/order_status.dart';
import '../../../domain/models/sale_order.dart';
import '../../../domain/pricing.dart';
import '../../../domain/repositories/sales_repository.dart';
import '../db_values.dart';
import '../sqlite_mappers.dart';

class SqliteSalesRepository implements SalesRepository {
  final Database _db;
  SqliteSalesRepository(this._db);

  @override
  Future<int> checkout({
    required List<CartLine> lines,
    required String paymentMethod,
    Discount? discount,
    DateTime? at,
  }) {
    return _db.transaction(
        (txn) => recordSale(txn, lines: lines, paymentMethod: paymentMethod, discount: discount, at: at));
  }

  /// The body of [checkout] on a given executor (also used to replay the
  /// demo history inside one transaction).
  static Future<int> recordSale(
    DatabaseExecutor txn, {
    required List<CartLine> lines,
    required String paymentMethod,
    Discount? discount,
    DateTime? at,
  }) async {
    if (lines.isEmpty) throw ArgumentError('Cart is empty');
    final now = at ?? DateTime.now();
    final discountPercent = discount?.percent ?? 0;

    // 1. Stock check (merging lines of the same variant). The arrival date
    //    is read here too, so the sale records the current one.
    final needed = <int, int>{};
    for (final l in lines) {
      needed[l.variant.id!] = (needed[l.variant.id!] ?? 0) + l.quantity;
    }
    final arrivals = <int, String>{};
    final problems = <String>[];
    for (final entry in needed.entries) {
      final rows = await txn.query('variants',
          columns: ['quantity', 'date_of_arrival'], where: 'id = ?', whereArgs: [entry.key]);
      final inStock = rows.isEmpty ? 0 : rows.first['quantity'] as int;
      if (rows.isNotEmpty) arrivals[entry.key] = rows.first['date_of_arrival'] as String;
      if (inStock < entry.value) {
        final line = lines.firstWhere((l) => l.variant.id == entry.key);
        problems.add('${line.product.name} (${line.variant.label}): ${entry.value} requested, $inStock in stock');
      }
    }
    if (problems.isNotEmpty) throw InsufficientStockException(problems);

    // 2. Totals.
    final computed = lines.map((l) => l.amounts(discountPercent)).toList();
    int sum(int Function(LineAmounts a) f) => computed.fold<int>(0, (s, a) => s + f(a));

    // 3. Workshop session running now?
    final ts = toDb(now);
    final sessionRows = await txn.query('calendar_events',
        columns: ['id'], where: 'start_at <= ? AND end_at > ?', whereArgs: [ts, ts], orderBy: 'start_at DESC', limit: 1);
    final sessionId = sessionRows.isEmpty ? null : sessionRows.first['id'] as int;

    final orderId = await txn.insert('orders', {
      'created_at': ts,
      'payment_method': paymentMethod,
      'status': OrderStatus.completed.code,
      'calendar_event_id': sessionId,
      'event_tag_source': sessionId == null ? null : 'auto',
      'discount_id': discount?.id,
      'discount_name': discount?.name,
      'discount_percent': discountPercent,
      'subtotal_cents': sum((a) => a.baseCents),
      'discount_cents': sum((a) => a.discountCents),
      'tax_cents': sum((a) => a.taxCents),
      'total_cents': sum((a) => a.totalCents),
    });

    // 4. Lines (with a snapshot of prices and rates) + stock decrement.
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final a = computed[i];
      await txn.insert('order_items', {
        'order_id': orderId,
        'variant_id': l.variant.id,
        'product_id': l.product.id,
        'artist_id': l.product.artistId,
        'product_name': l.product.name,
        'variant_label': l.variant.label,
        'category_name': l.product.categoryName,
        'quantity': l.quantity,
        'unit_base_cents': l.product.baseCentsFor(l.variant),
        'tax_percent': l.product.taxPercent,
        'commission_percent': l.product.commissionPercent,
        'discount_percent': discountPercent,
        'base_cents': a.baseCents,
        'discount_cents': a.discountCents,
        'tax_cents': a.taxCents,
        'total_cents': a.totalCents,
        'artist_payout_cents': a.artistPayoutCents,
        'arrival_date': arrivals[l.variant.id] ?? toDb(l.variant.dateOfArrival),
        'refunded_quantity': 0,
      });
      await txn.rawUpdate('UPDATE variants SET quantity = quantity - ? WHERE id = ?', [l.quantity, l.variant.id]);
    }
    return orderId;
  }

  @override
  Future<List<SaleOrder>> orders([OrderFilter filter = const OrderFilter()]) async {
    final where = <String>[];
    final args = <Object?>[];
    if (filter.range != null) {
      where.add('o.created_at >= ? AND o.created_at < ?');
      args.addAll([toDb(filter.range!.start), toDb(filter.range!.end)]);
    }
    if (filter.sessionId != null) {
      where.add('o.calendar_event_id = ?');
      args.add(filter.sessionId);
    }
    if (filter.query.trim().isNotEmpty) {
      where.add('o.id IN (SELECT order_id FROM order_items WHERE product_name LIKE ?)');
      args.add('%${filter.query.trim()}%');
    }
    final rows = await _db.rawQuery('''
      SELECT o.*, e.title AS event_title
      FROM orders o
      LEFT JOIN calendar_events e ON e.id = o.calendar_event_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY o.created_at DESC''', args);
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id']).toList();
    final itemRows = await _db.query('order_items',
        where: 'order_id IN (${placeholders(ids.length)})', whereArgs: ids, orderBy: 'id');
    final byOrder = <int, List<OrderItem>>{};
    for (final r in itemRows) {
      byOrder.putIfAbsent(r['order_id'] as int, () => []).add(SqliteMappers.orderItem(r));
    }
    return [for (final r in rows) SqliteMappers.order(r, byOrder[r['id']] ?? [])];
  }

  @override
  Future<SaleOrder?> order(int id) async {
    final rows = await _db.rawQuery('''
      SELECT o.*, e.title AS event_title FROM orders o
      LEFT JOIN calendar_events e ON e.id = o.calendar_event_id
      WHERE o.id = ?''', [id]);
    if (rows.isEmpty) return null;
    final items = await _db.query('order_items', where: 'order_id = ?', whereArgs: [id], orderBy: 'id');
    return SqliteMappers.order(rows.first, items.map(SqliteMappers.orderItem).toList());
  }

  @override
  Future<void> refund(int orderId, Map<int, int> quantities, {DateTime? at}) =>
      _db.transaction((txn) => recordRefund(txn, orderId, quantities, at: at));

  /// The body of [refund] on a given executor.
  static Future<void> recordRefund(DatabaseExecutor txn, int orderId, Map<int, int> quantities, {DateTime? at}) async {
    final now = toDb(at ?? DateTime.now());
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;
      final rows = await txn.query('order_items', where: 'id = ? AND order_id = ?', whereArgs: [entry.key, orderId]);
      if (rows.isEmpty) continue;
      final item = SqliteMappers.orderItem(rows.first);
      final q = entry.value.clamp(0, item.refundableQuantity);
      if (q == 0) continue;
      int share(int amount) => Pricing.refundShare(amount, item.quantity, item.refundedQuantity, q);

      await txn.insert('refunds', {
        'order_item_id': item.id,
        'quantity': q,
        'base_cents': share(item.baseCents),
        'tax_cents': share(item.taxCents),
        'total_cents': share(item.totalCents),
        'artist_payout_cents': share(item.artistPayoutCents),
        'created_at': now,
      });
      await txn.update('order_items', {'refunded_quantity': item.refundedQuantity + q},
          where: 'id = ?', whereArgs: [item.id]);
      if (item.variantId != null) {
        await txn.rawUpdate('UPDATE variants SET quantity = quantity + ? WHERE id = ?', [q, item.variantId]);
      }
    }

    final totals = await txn.rawQuery(
        'SELECT SUM(quantity) AS q, SUM(refunded_quantity) AS r FROM order_items WHERE order_id = ?', [orderId]);
    final q = (totals.first['q'] as int?) ?? 0;
    final r = (totals.first['r'] as int?) ?? 0;
    final status =
        r == 0 ? OrderStatus.completed : (r >= q ? OrderStatus.refunded : OrderStatus.partiallyRefunded);
    await txn.update('orders', {'status': status.code}, where: 'id = ?', whereArgs: [orderId]);
  }

  @override
  Future<void> setSession(int orderId, int? sessionId) => setSessionWith(_db, orderId, sessionId);

  static Future<void> setSessionWith(DatabaseExecutor ex, int orderId, int? sessionId) => ex.update(
      'orders', {'calendar_event_id': sessionId, 'event_tag_source': 'manual'},
      where: 'id = ?', whereArgs: [orderId]);
}
