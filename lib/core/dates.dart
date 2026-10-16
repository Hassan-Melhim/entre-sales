import 'package:intl/intl.dart';

final DateFormat _date = DateFormat('dd/MM/yyyy');
final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final DateFormat _monthYear = DateFormat('MMMM yyyy');

String formatDate(DateTime d) => _date.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d);
String formatMonth(DateTime d) => _monthYear.format(d);

/// Dates are stored as ISO-8601 local time strings, e.g. 2026-10-16T15:30:00.000
String toDb(DateTime d) => d.toIso8601String();
DateTime fromDb(String s) => DateTime.parse(s);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Exclusive end: the first moment of the next day.
DateTime endOfDayExclusive(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// A half-open time range [start, end).
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

  factory DateRange.month(int year, int month) =>
      DateRange(DateTime(year, month, 1), DateTime(year, month + 1, 1));

  /// The biweekly period immediately before this one (only valid for biweekly ranges).
  DateRange previousBiweekly() => DateRange.biweeklyContaining(start.subtract(const Duration(days: 1)));
  DateRange nextBiweekly() => DateRange.biweeklyContaining(end);
}
