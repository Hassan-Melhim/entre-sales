import 'package:intl/intl.dart';

final DateFormat _date = DateFormat('dd/MM/yyyy');
final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final DateFormat _time = DateFormat('HH:mm');
final DateFormat _monthYear = DateFormat('MMMM yyyy');

String formatDate(DateTime d) => _date.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d);
String formatTime(DateTime d) => _time.format(d);
String formatMonth(DateTime d) => _monthYear.format(d);

/// yyyymmdd, for file names.
String fileStamp(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

/// Dates are stored as ISO-8601 local time strings, e.g. 2026-10-16T15:30:00.000
String toDb(DateTime d) => d.toIso8601String();
DateTime fromDb(String s) => DateTime.parse(s);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Exclusive end: the first moment of the next day.
DateTime endOfDayExclusive(DateTime d) => DateTime(d.year, d.month, d.day + 1);
