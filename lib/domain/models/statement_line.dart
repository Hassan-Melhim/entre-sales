/// One sold (or refunded) line on an artist settlement.
class StatementLine {
  final DateTime date;
  final String orderNumber;
  final String productName;
  final String variantLabel;
  final int quantity;

  /// Before tax: the amount the commission was calculated on.
  final int baseCents;
  final double commissionPercent;
  final int payoutCents;

  /// [baseCents] with VAT added at the rate charged: the shelf price of
  /// these units (shown as "Full Price (+IVA)" on invoices; display only).
  final int fullPriceCents;

  const StatementLine({
    required this.date,
    required this.orderNumber,
    required this.productName,
    required this.variantLabel,
    required this.quantity,
    required this.baseCents,
    required this.commissionPercent,
    required this.payoutCents,
    required this.fullPriceCents,
  });

  int get commissionCents => baseCents - payoutCents;
}
