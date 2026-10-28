import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/cart_line.dart';
import '../../../domain/models/discount.dart';
import '../../../domain/models/order_filter.dart';
import '../../../domain/models/sale_order.dart';
import '../../../domain/repositories/sales_repository.dart';
import '../supabase_errors.dart';
import '../supabase_mappers.dart';
import '../supabase_paging.dart';
import '../supabase_values.dart';

/// Sales go through database functions (checkout, refund): prices, VAT and
/// commission are calculated there from the catalog, and stock is checked
/// and lowered in the same step.
class SupabaseSalesRepository implements SalesRepository {
  final SupabaseClient _db;
  SupabaseSalesRepository(this._db);

  @override
  Future<int> checkout(
          {required List<CartLine> lines, required String paymentMethod, Discount? discount, required String saleRef}) =>
      guard(() async {
        if (lines.isEmpty) throw ArgumentError('Cart is empty');
        final id = await _db.rpc('checkout', params: {
          'p_lines': [
            for (final l in lines) {'variant_id': l.variant.id, 'quantity': l.quantity},
          ],
          'p_payment_method': paymentMethod,
          'p_discount_id': discount?.id,
          'p_sale_ref': saleRef,
        });
        return asInt(id);
      });

  @override
  Future<List<SaleOrder>> orders([OrderFilter filter = const OrderFilter()]) => guard(() async {
        final rows = await fetchAllPages((from, to) => _db.rpc('search_orders', params: {
              'p_from': filter.range == null ? null : momentToDb(filter.range!.start),
              'p_to': filter.range == null ? null : momentToDb(filter.range!.end),
              'p_session_id': filter.sessionId,
              'p_query': filter.query.trim(),
            }).range(from, to));
        return rows.map(SupabaseMappers.order).toList();
      });

  @override
  Future<SaleOrder?> order(int id) => guard(() async {
        final row = await _db.from('order_rows').select().eq('id', id).maybeSingle();
        return row == null ? null : SupabaseMappers.order(row);
      });

  @override
  Future<void> refund(int orderId, Map<int, int> quantities) => guard(() => _db.rpc('refund', params: {
        'p_order_id': orderId,
        'p_items': {for (final e in quantities.entries) '${e.key}': e.value},
      }));

  @override
  Future<void> setSession(int orderId, int? sessionId) =>
      guard(() => _db.rpc('set_order_session', params: {'p_order_id': orderId, 'p_session_id': sessionId}));
}
