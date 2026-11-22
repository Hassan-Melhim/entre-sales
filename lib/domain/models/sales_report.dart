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

  /// Total sales: what customers paid, VAT included, net of refunds.
  final int revenueCents;
  final int vatCents;
  final int discountCents;
  final int refundsCents;

  /// What artists are paid, not counting the Spain-resident tax.
  final int artistPayoutCents;
  final int artistResidentTaxCents;

  /// Total sales − taxes − artist payouts.
  final int profitCents;

  /// Sales by payment method (Cash, Card…), most money first. Before refunds.
  final List<PaymentSplit> payments;

  /// Sales made during a workshop / event session vs. at other times.
  final SessionSplit sessions;

  /// What is on the shelf right now (not limited to the period). Null when
  /// the database hasn't been updated for it yet.
  final StockValue? stockValue;
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
    required this.payments,
    required this.sessions,
    required this.stockValue,
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

  /// VAT + Spain-resident artist tax.
  int get taxesCents => vatCents + artistResidentTaxCents;

  /// Total sales ÷ number of sales.
  int get averageSaleCents => orderCount == 0 ? 0 : (revenueCents / orderCount).round();

  /// Units sold ÷ number of sales.
  double get itemsPerSale => orderCount == 0 ? 0 : unitsSold / orderCount;

  /// Store profit as a share of sales before VAT.
  double? get marginPercent {
    final beforeVat = revenueCents - vatCents;
    return beforeVat <= 0 ? null : profitCents * 100 / beforeVat;
  }

  /// [byArtist] ordered by the store profit each artist brought in.
  List<Breakdown> get byArtistProfit => [...byArtist]..sort((a, b) => b.profitCents.compareTo(a.profitCents));
}

/// Sales paid one way (Cash, Card…).
class PaymentSplit {
  final String method;
  final int orders;
  final int revenueCents;
  const PaymentSplit(this.method, this.orders, this.revenueCents);
}

/// Sales during workshop / event sessions vs. at other times.
class SessionSplit {
  final int sessionCount;
  final int sessionOrders;
  final int sessionRevenueCents;
  final int otherOrders;
  final int otherRevenueCents;
  const SessionSplit({
    required this.sessionCount,
    required this.sessionOrders,
    required this.sessionRevenueCents,
    required this.otherOrders,
    required this.otherRevenueCents,
  });

  int get sessionAverageCents => sessionOrders == 0 ? 0 : (sessionRevenueCents / sessionOrders).round();
  int get otherAverageCents => otherOrders == 0 ? 0 : (otherRevenueCents / otherOrders).round();
}

/// The stock on the shelf, valued at today's prices and rates.
class StockValue {
  final int units;

  /// Shelf price, VAT included.
  final int shelfCents;

  /// What the store would keep if it all sold at full price.
  final int storeProfitCents;
  final int artistPayoutCents;
  final int taxesCents;

  /// Per artist, highest shelf value first.
  final List<StockValueRow> byArtist;

  const StockValue({
    required this.units,
    required this.shelfCents,
    required this.storeProfitCents,
    required this.artistPayoutCents,
    required this.taxesCents,
    required this.byArtist,
  });
}

class StockValueRow {
  final String artist;
  int units = 0;
  int shelfCents = 0;
  int storeProfitCents = 0;
  StockValueRow(this.artist);
}
