import 'breakdown.dart';
import 'category_turnover.dart';
import 'report_period.dart';
import 'shelf_life_row.dart';
import 'timeline_point.dart';

/// Everything shown on a sales report for one period. All money in cents.
class SalesReport {
  final ReportPeriod period;
  final int orderCount;
  final int unitsSold;
  final int unitsRefunded;

  /// Customer paid, VAT included, net of refunds.
  final int revenueCents;
  final int vatCents;
  final int discountCents;
  final int refundsCents;
  final int artistPayoutCents;
  final int artistResidentTaxCents;
  final int profitCents;
  final List<Breakdown> byCategory;
  final List<Breakdown> byArtist;
  final List<Breakdown> byGender;
  final List<Breakdown> topProducts;

  /// Revenue over the period (bar size depends on the period length).
  final List<TimelinePoint> timeline;

  /// 24 entries, index = hour of day.
  final List<int> revenueByHour;
  final List<int> ordersByHour;

  /// 7 entries, Monday first.
  final List<int> revenueByWeekday;
  final double? avgDaysToSell;
  final List<ShelfLifeRow> fastestSellers;
  final List<ShelfLifeRow> slowestSellers;

  /// Unsold stock, by days since arrival.
  final List<ShelfLifeRow> longestOnDisplay;
  final List<CategoryTurnover> turnover;

  const SalesReport({
    required this.period,
    required this.orderCount,
    required this.unitsSold,
    required this.unitsRefunded,
    required this.revenueCents,
    required this.vatCents,
    required this.discountCents,
    required this.refundsCents,
    required this.artistPayoutCents,
    required this.artistResidentTaxCents,
    required this.profitCents,
    required this.byCategory,
    required this.byArtist,
    required this.byGender,
    required this.topProducts,
    required this.timeline,
    required this.revenueByHour,
    required this.ordersByHour,
    required this.revenueByWeekday,
    required this.avgDaysToSell,
    required this.fastestSellers,
    required this.slowestSellers,
    required this.longestOnDisplay,
    required this.turnover,
  });

  bool get isEmpty => orderCount == 0 && refundsCents == 0;
}
