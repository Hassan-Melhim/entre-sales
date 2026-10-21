import 'package:intl/intl.dart';

final DateFormat _date = DateFormat('dd/MM/yyyy');
final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final DateFormat _time = DateFormat('HH:mm');
final DateFormat _monthYear = DateFormat('MMMM yyyy');
final DateFormat _longDate = DateFormat('EEE d MMM yyyy');
final DateFormat _shortMonth = DateFormat('MMM');
final DateFormat _dayMonth = DateFormat('d MMM');

String formatDate(DateTime d) => _date.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d);
String formatTime(DateTime d) => _time.format(d);
String formatMonth(DateTime d) => _monthYear.format(d);

/// e.g. "Wed 21 Oct 2026".
String formatLongDate(DateTime d) => _longDate.format(d);

/// e.g. "Oct".
String formatShortMonth(DateTime d) => _shortMonth.format(d);

/// e.g. "21 Oct".
String formatDayMonth(DateTime d) => _dayMonth.format(d);

/// yyyymmdd, for file names.
String fileStamp(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

/// ISO-8601 local time strings, e.g. 2026-10-16T15:30:00.000, used for storage.
String toDb(DateTime d) => d.toIso8601String();
DateTime fromDb(String s) => DateTime.parse(s);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Exclusive end: the first moment of the next day.
DateTime endOfDayExclusive(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// ISO-8601 week number (1–53).
int isoWeekNumber(DateTime d) {
  final thursday = DateTime(d.year, d.month, d.day + (4 - d.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final week1Monday = DateTime(firstThursday.year, 1, 4 - (firstThursday.weekday - 1));
  return 1 + DateTime.utc(thursday.year, thursday.month, thursday.day)
          .difference(DateTime.utc(week1Monday.year, week1Monday.month, week1Monday.day))
          .inDays ~/
      7;
}
