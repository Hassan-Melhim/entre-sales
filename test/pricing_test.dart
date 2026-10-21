import 'package:entre_sales/domain/business_rules.dart';
import 'package:entre_sales/domain/models/date_range.dart';
import 'package:entre_sales/domain/models/report_period.dart';
import 'package:entre_sales/domain/models/timeline_unit.dart';
import 'package:entre_sales/domain/pricing.dart';
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

  group('Date ranges', () {
    test('a whole month (payout period)', () {
      final r = DateRange.month(2026, 2);
      expect(r.start, DateTime(2026, 2, 1));
      expect(r.lastDay, DateTime(2026, 2, 28));
      expect(r.dayCount, 28);
    });

    test('start and end on the same day is one full day', () {
      final r = DateRange.days(DateTime(2026, 10, 16, 15, 30), DateTime(2026, 10, 16, 9));
      expect(r.start, DateTime(2026, 10, 16));
      expect(r.end, DateTime(2026, 10, 17));
      expect(r.isSingleDay, isTrue);
      expect(r.dayCount, 1);
    });

    test('quarters', () {
      expect(DateRange.quarter(2026, 1), DateRange(DateTime(2026, 1, 1), DateTime(2026, 4, 1)));
      expect(DateRange.quarter(2026, 4), DateRange(DateTime(2026, 10, 1), DateTime(2027, 1, 1)));
    });

    test('a year', () {
      expect(DateRange.year(2026).dayCount, 365);
    });
  });

  group('Report periods', () {
    test('quarter containing a date, and stepping across the year', () {
      final q = ReportPeriod.containing(PeriodKind.quarter, DateTime(2026, 11, 3));
      expect(q.label, 'Q4 2026');
      expect(q.fileLabel, '2026-Q4');
      expect(q.next().label, 'Q1 2027');
      expect(q.previous().label, 'Q3 2026');
    });

    test('day steps over the end of a month', () {
      final d = ReportPeriod.containing(PeriodKind.day, DateTime(2026, 10, 31));
      expect(d.next().range.start, DateTime(2026, 11, 1));
      expect(d.timelineUnit, TimelineUnit.hour);
    });

    test('timeline detail follows the length of the period', () {
      expect(ReportPeriod.containing(PeriodKind.month, DateTime(2026, 10)).timelineUnit, TimelineUnit.day);
      expect(ReportPeriod.containing(PeriodKind.quarter, DateTime(2026, 10)).timelineUnit, TimelineUnit.week);
      expect(ReportPeriod.containing(PeriodKind.year, DateTime(2026)).timelineUnit, TimelineUnit.month);
    });

    test('custom period cannot be stepped', () {
      final c = ReportPeriod.custom(DateRange.days(DateTime(2026, 10, 1), DateTime(2026, 10, 15)));
      expect(c.canStep, isFalse);
      expect(c.next(), c);
    });
  });
}
