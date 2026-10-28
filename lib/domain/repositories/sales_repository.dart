import '../models/cart_line.dart';
import '../models/discount.dart';
import '../models/order_filter.dart';
import '../models/sale_order.dart';

/// Sales, refunds and tagging sales with workshop sessions.
abstract interface class SalesRepository {
  /// Records a sale atomically: stock is re-checked and decremented in the
  /// same step, so two devices can never sell the same last unit.
  /// Sales during a workshop session are tagged automatically.
  /// [saleRef] identifies the attempt: sending the same sale again (e.g.
  /// after a lost connection) returns the first one instead of selling twice.
  /// Throws [InsufficientStockException].
  Future<int> checkout({
    required List<CartLine> lines,
    required String paymentMethod,
    Discount? discount,
    required String saleRef,
  });

  /// Newest first.
  Future<List<SaleOrder>> orders([OrderFilter filter = const OrderFilter()]);
  Future<SaleOrder?> order(int id);

  /// Refunds order item id → units. Items go back into stock. Dated now,
  /// so it counts in the payout period of the refund.
  Future<void> refund(int orderId, Map<int, int> quantities);

  /// Tags (or untags with null) a sale by hand. Manual tags are never
  /// overwritten by automatic tagging.
  Future<void> setSession(int orderId, int? sessionId);
}
