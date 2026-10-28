import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/date_range.dart';
import '../../../domain/models/order_summary.dart';
import '../../../domain/models/refunded_item.dart';
import '../../../domain/models/sold_item.dart';
import '../../../domain/models/stock_item.dart';
import '../../../domain/repositories/report_repository.dart';
import '../supabase_errors.dart';
import '../supabase_mappers.dart';
import '../supabase_paging.dart';
import '../supabase_values.dart';

/// Raw rows for reports, read page by page (a year can have thousands).
class SupabaseReportRepository implements ReportRepository {
  final SupabaseClient _db;
  SupabaseReportRepository(this._db);

  Map<String, dynamic> _range(DateRange r) => {'p_from': momentToDb(r.start), 'p_to': momentToDb(r.end)};

  Future<List<DbRow>> _all(String function, Map<String, dynamic> params) =>
      fetchAllPages((from, to) => _db.rpc(function, params: params).range(from, to));

  @override
  Future<List<OrderSummary>> orderSummaries(DateRange range) =>
      guard(() async => (await _all('report_order_summaries', _range(range))).map(SupabaseMappers.orderSummary).toList());

  @override
  Future<List<SoldItem>> soldItems(DateRange range, {int? artistId}) => guard(() async =>
      (await _all('report_sold_items', {..._range(range), 'p_artist_id': artistId})).map(SupabaseMappers.soldItem).toList());

  @override
  Future<List<RefundedItem>> refundedItems(DateRange range, {int? artistId}) => guard(() async =>
      (await _all('report_refunded_items', {..._range(range), 'p_artist_id': artistId}))
          .map(SupabaseMappers.refundedItem)
          .toList());

  @override
  Future<List<StockItem>> stockItems() =>
      guard(() async => (await _all('report_stock_items', const {})).map(SupabaseMappers.stockItem).toList());
}
