/// One sold line with the details reports need (artist, category, amounts).
/// Read-only fact produced by [ReportRepository].
class SoldItem {
  final int orderId;
  final DateTime soldAt;
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

  /// After discount, before tax.
  final int baseCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final double commissionPercent;
  final int artistPayoutCents;
  final DateTime? arrivalDate;

  const SoldItem({
    required this.orderId,
    required this.soldAt,
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
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    required this.commissionPercent,
    required this.artistPayoutCents,
    required this.arrivalDate,
  });
}
