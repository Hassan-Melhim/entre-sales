import '../core/dates.dart';
import '../core/db_values.dart';

/// One line of a sale. Prices and rates are copied at the moment of sale,
/// so editing a product or artist later never changes past sales.
class OrderItem {
  final int id;
  final int orderId;
  final int? variantId;
  final int artistId;
  final String productName;
  final String variantLabel;
  final String categoryName;
  final int quantity;
  final int unitBaseCents;
  final double taxPercent;
  final double commissionPercent;
  final double discountPercent;

  /// After discount, before tax.
  final int baseCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;

  /// Before the Spain-resident tax.
  final int artistPayoutCents;
  final DateTime? arrivalDate;
  final int refundedQuantity;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.variantId,
    required this.artistId,
    required this.productName,
    required this.variantLabel,
    required this.categoryName,
    required this.quantity,
    required this.unitBaseCents,
    required this.taxPercent,
    required this.commissionPercent,
    required this.discountPercent,
    required this.baseCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    required this.artistPayoutCents,
    this.arrivalDate,
    required this.refundedQuantity,
  });

  int get refundableQuantity => quantity - refundedQuantity;

  factory OrderItem.fromMap(Map<String, Object?> m) => OrderItem(
        id: m['id'] as int,
        orderId: m['order_id'] as int,
        variantId: m['variant_id'] as int?,
        artistId: m['artist_id'] as int,
        productName: m['product_name'] as String,
        variantLabel: m['variant_label'] as String,
        categoryName: m['category_name'] as String,
        quantity: m['quantity'] as int,
        unitBaseCents: m['unit_base_cents'] as int,
        taxPercent: doubleFromDb(m['tax_percent'])!,
        commissionPercent: doubleFromDb(m['commission_percent'])!,
        discountPercent: doubleFromDb(m['discount_percent'])!,
        baseCents: m['base_cents'] as int,
        discountCents: m['discount_cents'] as int,
        taxCents: m['tax_cents'] as int,
        totalCents: m['total_cents'] as int,
        artistPayoutCents: m['artist_payout_cents'] as int,
        arrivalDate: m['arrival_date'] == null ? null : fromDb(m['arrival_date'] as String),
        refundedQuantity: m['refunded_quantity'] as int,
      );
}
