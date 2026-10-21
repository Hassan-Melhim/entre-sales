import '../core/money.dart';
import 'business_rules.dart';
import 'models/line_amounts.dart';

/// All money formulas. The rules they follow are in business_rules.dart.
class Pricing {
  Pricing._();

  /// Unit price including tax, for display on the shelf / POS.
  static int unitPriceWithTax(int unitBaseCents, double taxPercent) =>
      roundCents(unitBaseCents * (1 + taxPercent / 100));

  static LineAmounts line({
    required int unitBaseCents,
    required int quantity,
    required double taxPercent,
    required double discountPercent,
    required double commissionPercent,
  }) {
    final grossBase = unitBaseCents * quantity;
    final base = roundCents(grossBase * (1 - discountPercent / 100));
    final tax = roundCents(base * taxPercent / 100);
    // See BusinessRules.discountReducesArtistPayout
    final payoutBase = BusinessRules.discountReducesArtistPayout ? base : grossBase;
    final payout = roundCents(payoutBase * (1 - commissionPercent / 100));
    return LineAmounts(
      grossBaseCents: grossBase,
      baseCents: base,
      taxCents: tax,
      totalCents: base + tax,
      payoutBaseCents: payoutBase,
      artistPayoutCents: payout,
    );
  }

  /// Share of [lineAmount] for refunding [refundQty] units when
  /// [alreadyRefundedQty] units of a [lineQty]-unit line were refunded before.
  /// Computed so that refunding every unit returns exactly [lineAmount].
  static int refundShare(int lineAmount, int lineQty, int alreadyRefundedQty, int refundQty) {
    final before = roundCents(lineAmount * alreadyRefundedQty / lineQty);
    final after = roundCents(lineAmount * (alreadyRefundedQty + refundQty) / lineQty);
    return after - before;
  }

  /// Spain-resident tax on an artist's payout (always a positive amount).
  static int residentTax(int payoutCents, double ratePercent) => roundCents(payoutCents * ratePercent / 100);

  /// Final amount the store pays the artist.
  /// See BusinessRules.residentTaxAddedOnTop.
  static int artistNetPayout({required int payoutCents, required bool spainResident}) {
    if (!spainResident) return payoutCents;
    final tax = residentTax(payoutCents, BusinessRules.spainResidentArtistTaxPercent);
    return BusinessRules.residentTaxAddedOnTop ? payoutCents + tax : payoutCents - tax;
  }

  /// Store profit for a set of sales. See BusinessRules.profitSubtractsArtistResidentTax.
  static int storeProfit({
    required int customerPaidCents,
    required int artistPayoutCents,
    required int artistResidentTaxAddedCents,
  }) {
    var profit = customerPaidCents - artistPayoutCents;
    if (BusinessRules.profitSubtractsArtistResidentTax && BusinessRules.residentTaxAddedOnTop) {
      profit -= artistResidentTaxAddedCents;
    }
    return profit;
  }
}
