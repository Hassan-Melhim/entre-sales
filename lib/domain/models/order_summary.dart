/// Totals of one sale, without its lines (for counting and time charts).
class OrderSummary {
  final int id;
  final DateTime createdAt;
  final String paymentMethod;
  final int discountCents;
  final int taxCents;
  final int totalCents;

  /// The workshop / event session running when the sale was made, if any.
  final int? sessionId;

  const OrderSummary({
    required this.id,
    required this.createdAt,
    required this.paymentMethod,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    this.sessionId,
  });
}
