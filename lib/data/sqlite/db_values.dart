/// Helpers for reading SQLite values (SQLite has no bool type, and REAL
/// columns can come back as int when the value is whole).
bool boolFromDb(Object? v) => v == 1 || v == true;

double? doubleFromDb(Object? v) => v == null ? null : (v as num).toDouble();

/// The first column of the first row as an int (e.g. for COUNT(*)), or 0.
int firstInt(List<Map<String, Object?>> rows) =>
    rows.isEmpty || rows.first.values.isEmpty ? 0 : ((rows.first.values.first as num?)?.toInt() ?? 0);

/// "?, ?, ?" for an IN (...) clause with [n] values.
String placeholders(int n) => List.filled(n, '?').join(',');
