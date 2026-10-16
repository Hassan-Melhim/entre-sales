import 'package:entre_sales/config/business_rules.dart';
import 'package:entre_sales/core/dates.dart';
import 'package:entre_sales/core/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sale line', () {
    test('100 € piece, 21% VAT, 35% commission', () {
      final a = Pricing.line(
          unitBaseCents: 10000, quantity: 1, taxPercent: 21, discountPercent: 0, commissionPercent: 35);
      expect(a.baseCents, 10000);
      expect(a.taxCents, 2100);
      expect(a.totalCents, 12100);
      expect(a.artistPayoutCents, 6500);
    });

    test('books use 4% VAT', () {
      final a = Pricing.line(
          unitBaseCents: 2000, quantity: 2, taxPercent: 4, discountPercent: 0, commissionPercent: 35);
      expect(a.totalCents, 4160);
    });

    test('5% Friends & Family discount', () {
      final a = Pricing.line(
          unitBaseCents: 10000, quantity: 1, taxPercent: 21, discountPercent: 5, commissionPercent: 35);
      expect(a.baseCents, 9500);
      expect(a.totalCents, 11495);
      expect(a.artistPayoutCents, BusinessRules.discountReducesArtistPayout ? 6175 : 6500);
    });
  });

  test('Spain-resident artist tax', () {
    final net = Pricing.artistNetPayout(payoutCents: 6500, spainResident: true);
    expect(net, BusinessRules.residentTaxAddedOnTop ? 7150 : 5850);
    expect(Pricing.artistNetPayout(payoutCents: 6500, spainResident: false), 6500);
  });

  test('partial refunds add up to the full line', () {
    const total = 3631; // 3 units, awkward to divide
    final first = Pricing.refundShare(total, 3, 0, 1);
    final second = Pricing.refundShare(total, 3, 1, 2);
    expect(first + second, total);
  });

  group('Payout periods', () {
    test('1st–15th', () {
      final r = DateRange.biweeklyContaining(DateTime(2026, 10, 9));
      expect(r.start, DateTime(2026, 10, 1));
      expect(r.lastDay, DateTime(2026, 10, 15));
    });
    test('16th–end of month', () {
      final r = DateRange.biweeklyContaining(DateTime(2026, 2, 20));
      expect(r.start, DateTime(2026, 2, 16));
      expect(r.lastDay, DateTime(2026, 2, 28));
    });
    test('15 days ending on a chosen date', () {
      final r = DateRange.daysEndingOn(DateTime(2026, 10, 16), 15);
      expect(r.start, DateTime(2026, 10, 2));
      expect(r.lastDay, DateTime(2026, 10, 16));
    });
  });
}
