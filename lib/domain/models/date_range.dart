import '../../core/dates.dart';

/// A half-open time range [start, end).
///
/// Has value equality, so it can be used directly as a Riverpod family key.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  /// Last day included in the range (for display).
  DateTime get lastDay => end.subtract(const Duration(days: 1));

  /// Number of calendar days covered.
  int get dayCount => DateTime.utc(end.year, end.month, end.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;

  bool get isSingleDay => dayCount == 1;

  String get label => isSingleDay ? formatDate(start) : '${formatDate(start)} – ${formatDate(lastDay)}';

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  /// Whole days from [first] to [last], both included. [first] and [last]
  /// may be the same day.
  factory DateRange.days(DateTime first, DateTime last) => DateRange(startOfDay(first), endOfDayExclusive(last));

  factory DateRange.day(DateTime d) => DateRange.days(d, d);

  factory DateRange.month(int year, int month) => DateRange(DateTime(year, month, 1), DateTime(year, month + 1, 1));

  /// [quarter] is 1–4.
  factory DateRange.quarter(int year, int quarter) =>
      DateRange(DateTime(year, (quarter - 1) * 3 + 1, 1), DateTime(year, quarter * 3 + 1, 1));

  factory DateRange.year(int year) => DateRange(DateTime(year, 1, 1), DateTime(year + 1, 1, 1));

  @override
  bool operator ==(Object other) => other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
