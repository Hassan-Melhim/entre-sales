/// Units of a sold line that were refunded, dated on the day of the refund.
/// Read-only fact produced by [ReportRepository].
class RefundedItem {
  final int orderId;
  final DateTime refundedAt;
  final int artistId;
  final String artistName;
  final String? artistGender;
  final bool artistResident;
  final int? productId;
  final String productName;
  final String variantLabel;
  final String categoryName;
  final int quantity;
  final int unitBaseCents;
  final int baseCents;
  final int taxCents;
  final int totalCents;
  final double commissionPercent;
  final int artistPayoutCents;

  const RefundedItem({
    required this.orderId,
    required this.refundedAt,
    required this.artistId,
    required this.artistName,
    required this.artistGender,
    required this.artistResident,
    required this.productId,
    required this.productName,
    required this.variantLabel,
    required this.categoryName,
    required this.quantity,
    required this.unitBaseCents,
    required this.baseCents,
    required this.taxCents,
    required this.totalCents,
    required this.commissionPercent,
    required this.artistPayoutCents,
  });
}
