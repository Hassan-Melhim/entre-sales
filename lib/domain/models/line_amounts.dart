/// Money amounts for one line of a sale (one variant × quantity), in cents.
class LineAmounts {
  /// Price before tax and before discount (unit base × quantity).
  final int grossBaseCents;

  /// Price before tax, after discount. This is the taxable base.
  final int baseCents;
  final int taxCents;

  /// What the customer pays for the line: [baseCents] + [taxCents].
  final int totalCents;

  /// The amount the artist's commission is calculated on.
  final int payoutBaseCents;

  /// What the artist earns for this line (before the Spain-resident tax).
  final int artistPayoutCents;

  const LineAmounts({
    required this.grossBaseCents,
    required this.baseCents,
    required this.taxCents,
    required this.totalCents,
    required this.payoutBaseCents,
    required this.artistPayoutCents,
  });

  int get discountCents => grossBaseCents - baseCents;
}
