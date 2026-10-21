import '../models/date_range.dart';
import '../models/order_summary.dart';
import '../models/refunded_item.dart';
import '../models/sold_item.dart';
import '../models/stock_item.dart';

/// Raw facts for reports and artist settlements. The calculations themselves
/// live in the domain services, so they work the same with any database.
abstract interface class ReportRepository {
  Future<List<OrderSummary>> orderSummaries(DateRange range);

  /// Sold lines in [range] (by sale date), optionally for one artist.
  Future<List<SoldItem>> soldItems(DateRange range, {int? artistId});

  /// Refunds made in [range] (by refund date), optionally for one artist.
  Future<List<RefundedItem>> refundedItems(DateRange range, {int? artistId});

  /// Variants currently in stock.
  Future<List<StockItem>> stockItems();
}
