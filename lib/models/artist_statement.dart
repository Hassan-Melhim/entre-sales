import '../config/business_rules.dart';
import '../core/pricing.dart';
import 'artist.dart';
import 'date_range.dart';
import 'statement_line.dart';

/// What the store owes one artist for one period.
class ArtistStatement {
  final Artist artist;
  final DateRange range;
  final List<StatementLine> sales;

  /// Refunds made during this period (deducted).
  final List<StatementLine> refunds;

  const ArtistStatement({required this.artist, required this.range, required this.sales, required this.refunds});

  int _sum(List<StatementLine> l, int Function(StatementLine) f) => l.fold(0, (s, x) => s + f(x));

  int get soldUnits => _sum(sales, (l) => l.quantity) - _sum(refunds, (l) => l.quantity);
  int get salesBaseCents => _sum(sales, (l) => l.baseCents) - _sum(refunds, (l) => l.baseCents);
  int get payoutCents => _sum(sales, (l) => l.payoutCents) - _sum(refunds, (l) => l.payoutCents);
  int get commissionCents => salesBaseCents - payoutCents;

  double get residentTaxPercent => artist.isSpainResident ? BusinessRules.spainResidentArtistTaxPercent : 0;
  int get residentTaxCents =>
      artist.isSpainResident ? Pricing.residentTax(payoutCents, BusinessRules.spainResidentArtistTaxPercent) : 0;
  int get netPayoutCents => Pricing.artistNetPayout(payoutCents: payoutCents, spainResident: artist.isSpainResident);

  bool get isEmpty => sales.isEmpty && refunds.isEmpty;
}
