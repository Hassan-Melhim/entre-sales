import 'date_range.dart';

/// Search and filters for the sales list.
class OrderFilter {
  final DateRange? range;
  final int? sessionId;
  final String query;

  const OrderFilter({this.range, this.sessionId, this.query = ''});

  @override
  bool operator ==(Object other) =>
      other is OrderFilter && other.range == range && other.sessionId == sessionId && other.query == query;

  @override
  int get hashCode => Object.hash(range, sessionId, query);
}
