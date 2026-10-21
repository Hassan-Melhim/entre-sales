import 'dart:async';

import '../models/artist.dart';
import '../models/artist_statement.dart';
import '../models/date_range.dart';
import '../models/report_period.dart';
import '../models/sales_report.dart';
import '../repositories/report_repository.dart';
import 'artist_statement_builder.dart';
import 'sales_report_builder.dart';

/// Reports and artist settlements: fetches facts, then calculates.
class ReportService {
  final ReportRepository _facts;
  ReportService(this._facts);

  Future<SalesReport> salesReport(ReportPeriod period) async {
    final range = period.range;
    final (orders, sold, refunds, stock) = await (
      _facts.orderSummaries(range),
      _facts.soldItems(range),
      _facts.refundedItems(range),
      _facts.stockItems(),
    ).wait;
    return SalesReportBuilder.build(period: period, orders: orders, sold: sold, refunds: refunds, stock: stock);
  }

  /// Settlements for every artist with activity in [range].
  Future<List<ArtistStatement>> statements(List<Artist> artists, DateRange range) async {
    final sold = await _facts.soldItems(range);
    final refunds = await _facts.refundedItems(range);
    return ArtistStatementBuilder.buildAll(artists: artists, range: range, sold: sold, refunds: refunds);
  }

  Future<ArtistStatement> statement(Artist artist, DateRange range) async {
    final sold = await _facts.soldItems(range, artistId: artist.id);
    final refunds = await _facts.refundedItems(range, artistId: artist.id);
    return ArtistStatementBuilder.build(artist: artist, range: range, sold: sold, refunds: refunds);
  }
}
