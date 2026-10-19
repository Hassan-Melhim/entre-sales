import '../core/dates.dart';

/// A half-open time range [start, end).
///
/// Has value equality, so it can be used directly as a Riverpod family key.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  /// Last day included in the range (for display).
  DateTime get lastDay => end.subtract(const Duration(days: 1));

  String get label => '${formatDate(start)} – ${formatDate(lastDay)}';

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  /// Biweekly period that contains [d]: 1st–15th or 16th–end of month.
  factory DateRange.biweeklyContaining(DateTime d) {
    if (d.day <= 15) {
      return DateRange(DateTime(d.year, d.month, 1), DateTime(d.year, d.month, 16));
    }
    return DateRange(DateTime(d.year, d.month, 16), DateTime(d.year, d.month + 1, 1));
  }

  /// The [days] days ending on (and including) [lastDay].
  factory DateRange.daysEndingOn(DateTime lastDay, int days) {
    final end = endOfDayExclusive(lastDay);
    return DateRange(DateTime(end.year, end.month, end.day - days), end);
  }

  factory DateRange.month(int year, int month) => DateRange(DateTime(year, month, 1), DateTime(year, month + 1, 1));

  /// Whole days from [first] to [last], both included.
  factory DateRange.days(DateTime first, DateTime last) => DateRange(startOfDay(first), endOfDayExclusive(last));

  /// The biweekly period immediately before / after this one.
  DateRange previousBiweekly() => DateRange.biweeklyContaining(start.subtract(const Duration(days: 1)));
  DateRange nextBiweekly() => DateRange.biweeklyContaining(end);

  @override
  bool operator ==(Object other) => other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
