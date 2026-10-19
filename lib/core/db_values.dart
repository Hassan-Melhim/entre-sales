/// Helpers for reading SQLite values (SQLite has no bool type, and REAL
/// columns can come back as int when the value is whole).
bool boolFromDb(Object? v) => v == 1 || v == true;

double? doubleFromDb(Object? v) => v == null ? null : (v as num).toDouble();
