import 'date_range.dart';

/// Search and filters for the sales list.
class OrderFilter {
  final DateRange? range;
  final int? sessionId;
  final String query;

  /// Sales with at least one item in this category (the whole sale is listed).
  final int? categoryId;

  const OrderFilter({this.range, this.sessionId, this.query = '', this.categoryId});

  @override
  bool operator ==(Object other) =>
      other is OrderFilter &&
      other.range == range &&
      other.sessionId == sessionId &&
      other.query == query &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(range, sessionId, query, categoryId);
}
