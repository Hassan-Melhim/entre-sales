import 'dart:math' as math;

import '../../core/dates.dart';
import '../business_rules.dart';
import '../models/breakdown.dart';
import '../models/category_turnover.dart';
import '../models/order_summary.dart';
import '../models/refunded_item.dart';
import '../models/report_period.dart';
import '../models/sales_report.dart';
import '../models/shelf_life_row.dart';
import '../models/sold_item.dart';
import '../models/stock_item.dart';
import '../models/timeline_point.dart';
import '../models/timeline_unit.dart';
import '../pricing.dart';

/// Turns raw sales facts into a [SalesReport]. Pure calculation: no database.
class SalesReportBuilder {
  SalesReportBuilder._();

  static SalesReport build({
    required ReportPeriod period,
    required List<OrderSummary> orders,
    required List<SoldItem> sold,
    required List<RefundedItem> refunds,
    required List<StockItem> stock,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    // --- Totals
    final refundsTotal = refunds.fold<int>(0, (s, r) => s + r.totalCents);
    final revenue = orders.fold<int>(0, (s, o) => s + o.totalCents) - refundsTotal;
    final vat = orders.fold<int>(0, (s, o) => s + o.taxCents) - refunds.fold<int>(0, (s, r) => s + r.taxCents);
    final discounts = orders.fold<int>(0, (s, o) => s + o.discountCents);
    final unitsRefunded = refunds.fold<int>(0, (s, r) => s + r.quantity);
    final unitsSold = sold.fold<int>(0, (s, i) => s + i.quantity) - unitsRefunded;

    // --- Artist payouts, per artist (needed for the Spain-resident tax)
    final payoutByArtist = <int, int>{};
    final residentByArtist = <int, bool>{};
    for (final i in sold) {
      payoutByArtist[i.artistId] = (payoutByArtist[i.artistId] ?? 0) + i.artistPayoutCents;
      residentByArtist[i.artistId] = i.artistResident;
    }
    for (final r in refunds) {
      payoutByArtist[r.artistId] = (payoutByArtist[r.artistId] ?? 0) - r.artistPayoutCents;
      residentByArtist[r.artistId] = r.artistResident;
    }
    var payout = 0;
    var residentTax = 0;
    payoutByArtist.forEach((id, p) {
      payout += p;
      if (residentByArtist[id] == true) {
        residentTax += Pricing.residentTax(p, BusinessRules.spainResidentArtistTaxPercent);
      }
    });
    final profit = Pricing.storeProfit(
      customerPaidCents: revenue,
      artistPayoutCents: payout,
      artistResidentTaxAddedCents: residentTax,
    );

    // --- Breakdowns (sales minus refunds)
    final byCategory = <String, Breakdown>{};
    final byArtist = <String, Breakdown>{};
    final byGender = <String, Breakdown>{};
    final byProduct = <String, Breakdown>{};
    void add(String category, String artist, String? gender, String product, int units, int rev, int prof) {
      for (final (map, key) in [
        (byCategory, category),
        (byArtist, artist),
        (byGender, gender ?? 'Not set'),
        (byProduct, '$product — $artist'),
      ]) {
        map.putIfAbsent(key, () => Breakdown(key)).add(units: units, revenueCents: rev, profitCents: prof);
      }
    }

    for (final i in sold) {
      add(i.categoryName, i.artistName, i.artistGender, i.productName, i.quantity, i.totalCents,
          i.totalCents - i.artistPayoutCents);
    }
    for (final r in refunds) {
      add(r.categoryName, r.artistName, r.artistGender, r.productName, -r.quantity, -r.totalCents,
          -r.totalCents + r.artistPayoutCents);
    }
    List<Breakdown> sorted(Map<String, Breakdown> m) =>
        m.values.toList()..sort((a, b) => b.revenueCents.compareTo(a.revenueCents));

    // --- Time of sale
    final revenueByHour = List<int>.filled(24, 0);
    final ordersByHour = List<int>.filled(24, 0);
    final revenueByWeekday = List<int>.filled(7, 0);
    for (final o in orders) {
      revenueByHour[o.createdAt.hour] += o.totalCents;
      ordersByHour[o.createdAt.hour] += 1;
      revenueByWeekday[o.createdAt.weekday - 1] += o.totalCents;
    }

    // --- Shelf life: days from arrival to sale, for items sold in the period
    final shelf = <String, _ShelfAcc>{};
    final catDays = <String, _ShelfAcc>{};
    var allDays = 0.0;
    var allUnits = 0;
    for (final i in sold) {
      final arrival = i.arrivalDate;
      if (arrival == null) continue;
      final days = i.soldAt.difference(arrival).inHours / 24;
      shelf
          .putIfAbsent('${i.productId ?? i.productName}', () => _ShelfAcc(i.productName, i.artistName, i.categoryName))
          .add(days, i.quantity);
      catDays.putIfAbsent(i.categoryName, () => _ShelfAcc('', '', i.categoryName)).add(days, i.quantity);
      allDays += days * i.quantity;
      allUnits += i.quantity;
    }
    final shelfRows = shelf.values.map((a) => a.row()).toList()..sort((a, b) => a.days.compareTo(b.days));

    // --- Current stock: how long unsold items have been on display
    final onDisplay = <int, _DisplayAcc>{};
    final stockByCategory = <String, int>{};
    for (final s in stock) {
      onDisplay.putIfAbsent(s.productId, () => _DisplayAcc(s)).add(s, today);
      stockByCategory[s.categoryName] = (stockByCategory[s.categoryName] ?? 0) + s.quantity;
    }
    final longest = onDisplay.values.map((a) => a.row()).toList()..sort((a, b) => b.days.compareTo(a.days));

    final categories = {...byCategory.keys, ...stockByCategory.keys}.toList()..sort();
    final turnover = [
      for (final c in categories)
        CategoryTurnover(c, byCategory[c]?.units ?? 0, stockByCategory[c] ?? 0, catDays[c]?.row().days),
    ];

    return SalesReport(
      period: period,
      orderCount: orders.length,
      unitsSold: unitsSold,
      unitsRefunded: unitsRefunded,
      revenueCents: revenue,
      vatCents: vat,
      discountCents: discounts,
      refundsCents: refundsTotal,
      artistPayoutCents: payout,
      artistResidentTaxCents: residentTax,
      profitCents: profit,
      byCategory: sorted(byCategory),
      byArtist: sorted(byArtist),
      byGender: sorted(byGender),
      topProducts: sorted(byProduct).take(15).toList(),
      timeline: timeline(period, orders),
      revenueByHour: revenueByHour,
      ordersByHour: ordersByHour,
      revenueByWeekday: revenueByWeekday,
      avgDaysToSell: allUnits == 0 ? null : allDays / allUnits,
      fastestSellers: shelfRows.take(10).toList(),
      slowestSellers: shelfRows.reversed.take(10).toList(),
      longestOnDisplay: longest.take(10).toList(),
      turnover: turnover,
    );
  }

  /// Revenue per hour / day / week / month, depending on the period length.
  static List<TimelinePoint> timeline(ReportPeriod period, List<OrderSummary> orders) {
    final unit = period.timelineUnit;
    final range = period.range;

    // Bucket start times.
    final starts = <DateTime>[];
    switch (unit) {
      case TimelineUnit.hour:
        // Opening hours only: first to last hour with sales (or 10–21).
        final hours = orders.map((o) => o.createdAt.hour).toList();
        final first = hours.isEmpty ? 10 : hours.reduce(math.min);
        final last = hours.isEmpty ? 20 : hours.reduce(math.max);
        for (var h = first; h <= last; h++) {
          starts.add(DateTime(range.start.year, range.start.month, range.start.day, h));
        }
      case TimelineUnit.day:
        for (var d = range.start; d.isBefore(range.end); d = DateTime(d.year, d.month, d.day + 1)) {
          starts.add(d);
        }
      case TimelineUnit.week:
        for (var d = startOfWeek(range.start); d.isBefore(range.end); d = DateTime(d.year, d.month, d.day + 7)) {
          starts.add(d);
        }
      case TimelineUnit.month:
        for (var d = DateTime(range.start.year, range.start.month);
            d.isBefore(range.end);
            d = DateTime(d.year, d.month + 1)) {
          starts.add(d);
        }
    }

    final revenue = List<int>.filled(starts.length, 0);
    final count = List<int>.filled(starts.length, 0);
    for (final o in orders) {
      // Last bucket that starts at or before the order.
      var i = starts.length - 1;
      while (i >= 0 && starts[i].isAfter(o.createdAt)) {
        i--;
      }
      if (i < 0) continue;
      revenue[i] += o.totalCents;
      count[i] += 1;
    }

    return [
      for (var i = 0; i < starts.length; i++)
        TimelinePoint(
          start: starts[i],
          label: _shortLabel(unit, starts[i]),
          longLabel: _longLabel(unit, starts[i]),
          revenueCents: revenue[i],
          orders: count[i],
        ),
    ];
  }

  static String _shortLabel(TimelineUnit unit, DateTime d) => switch (unit) {
        TimelineUnit.hour => '${d.hour}h',
        TimelineUnit.day => '${d.day}',
        TimelineUnit.week => 'W${isoWeekNumber(d)}',
        TimelineUnit.month => formatShortMonth(d),
      };

  static String _longLabel(TimelineUnit unit, DateTime d) => switch (unit) {
        TimelineUnit.hour =>
          '${d.hour.toString().padLeft(2, '0')}:00–${(d.hour + 1).toString().padLeft(2, '0')}:00',
        TimelineUnit.day => formatLongDate(d),
        TimelineUnit.week => 'Week ${isoWeekNumber(d)} (from ${formatDayMonth(d)})',
        TimelineUnit.month => formatMonth(d),
      };
}

class _ShelfAcc {
  final String product;
  final String artist;
  final String category;
  double weightedDays = 0;
  int units = 0;
  _ShelfAcc(this.product, this.artist, this.category);

  void add(double days, int u) {
    weightedDays += days * u;
    units += u;
  }

  ShelfLifeRow row() => ShelfLifeRow(product, artist, category, units == 0 ? 0 : weightedDays / units, units);
}

/// Unsold units of one product: oldest arrival and total units.
class _DisplayAcc {
  final StockItem first;
  double maxDays = 0;
  int units = 0;
  _DisplayAcc(this.first);

  void add(StockItem s, DateTime now) {
    maxDays = math.max(maxDays, now.difference(s.arrival).inHours / 24);
    units += s.quantity;
  }

  ShelfLifeRow row() => ShelfLifeRow(first.productName, first.artistName, first.categoryName, maxDays, units);
}
