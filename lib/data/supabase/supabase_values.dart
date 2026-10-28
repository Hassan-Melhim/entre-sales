// Converting between Supabase (JSON from PostgREST) and Dart values.
//
// Times are stored in UTC and shown in the device's time (Madrid);
// days (date of arrival) are plain dates with no time zone.

int asInt(Object? v) => (v as num).toInt();
int? asIntOrNull(Object? v) => v == null ? null : (v as num).toInt();
double asDouble(Object? v) => (v as num).toDouble();
double? asDoubleOrNull(Object? v) => v == null ? null : (v as num).toDouble();
bool asBool(Object? v) => v as bool;

/// A moment from the database, in local time.
DateTime parseMoment(Object? v) => DateTime.parse(v as String).toLocal();

/// A moment for the database (UTC, ISO 8601).
String momentToDb(DateTime d) => d.toUtc().toIso8601String();

/// A day from the database ("2026-10-28"), as local midnight.
DateTime parseDay(Object? v) {
  final d = DateTime.parse(v as String);
  return DateTime(d.year, d.month, d.day);
}

DateTime? parseDayOrNull(Object? v) => v == null ? null : parseDay(v);

/// A day for the database ("2026-10-28"), using the local calendar date.
String dayToDb(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// JSON object → ordered map of strings (variant fields keep their order).
Map<String, String> asStringMap(Object? v) =>
    v == null ? const {} : (v as Map).map((k, val) => MapEntry('$k', '$val'));

List<String> asStringList(Object? v) => v == null ? const [] : (v as List).map((e) => '$e').toList();

typedef DbRow = Map<String, dynamic>;

List<DbRow> asRows(Object? v) => v == null ? const [] : (v as List).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
