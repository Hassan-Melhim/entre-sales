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
}
