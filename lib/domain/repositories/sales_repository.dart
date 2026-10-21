import '../models/cart_line.dart';
import '../models/discount.dart';
import '../models/order_filter.dart';
import '../models/sale_order.dart';

/// Sales, refunds and tagging sales with workshop sessions.
abstract interface class SalesRepository {
  /// Records a sale atomically: stock is re-checked and decremented in the
  /// same step, so two devices can never sell the same last unit.
  /// Sales during a workshop session are tagged automatically.
  /// Throws [InsufficientStockException].
  Future<int> checkout({
    required List<CartLine> lines,
    required String paymentMethod,
    Discount? discount,
    DateTime? at,
  });

  /// Newest first.
  Future<List<SaleOrder>> orders([OrderFilter filter = const OrderFilter()]);
  Future<SaleOrder?> order(int id);

  /// Refunds order item id → units. Items go back into stock. Dated now
  /// (or [at]), so it counts in the payout period of the refund.
  Future<void> refund(int orderId, Map<int, int> quantities, {DateTime? at});

  /// Tags (or untags with null) a sale by hand. Manual tags are never
  /// overwritten by automatic tagging.
  Future<void> setSession(int orderId, int? sessionId);
}
