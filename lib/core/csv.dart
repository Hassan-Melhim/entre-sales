import 'dart:convert';

/// Reading CSV files as Excel saves them, in any of its flavours:
/// comma, semicolon (Spanish Excel) or tab separated; UTF-8 (with or without
/// a BOM) or the older Windows encoding; fields in "quotes" with "" inside.

/// Bytes → text. Tries UTF-8 first, then Windows-1252 (Excel's "CSV" on
/// Windows / older Macs), so accents and € come out right either way.
String decodeCsvBytes(List<int> bytes) {
  var b = bytes;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) b = b.sublist(3);
  try {
    return utf8.decode(b);
  } on FormatException {
    return String.fromCharCodes(b.map((c) => _cp1252[c] ?? c));
  }
}

/// The Windows-1252 characters that differ from Latin-1.
const Map<int, int> _cp1252 = {
  0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021,
  0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018,
  0x92: 0x2019, 0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC,
  0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
};

/// Text → rows of fields. The separator is guessed from the first line.
List<List<String>> parseCsv(String text) {
  final firstLine = text.split(RegExp(r'\r?\n')).first;
  final sep = [';', ',', '\t'].reduce((a, b) => _countOutsideQuotes(firstLine, a) >= _countOutsideQuotes(firstLine, b) ? a : b);

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == sep) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

int _countOutsideQuotes(String line, String sep) {
  var n = 0;
  var inQuotes = false;
  for (final ch in line.split('')) {
    if (ch == '"') inQuotes = !inQuotes;
    if (!inQuotes && ch == sep) n++;
  }
  return n;
}

/// A header made comparable: lowercase letters and digits only, so
/// "Price incl. VAT (€) *" and "price incl vat" match.
String normalizeHeader(String h) => h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// "25", "25.50", "25,50", "1.234,50", "1,234.50", "€ 25", "25 €" → cents.
int? parseFlexibleCents(String input) {
  final n = parseFlexibleNumber(input.replaceAll('€', '').replaceAll('EUR', ''));
  return n == null ? null : (n * 100).round();
}

/// A number written with a decimal comma or dot, with or without thousands.
double? parseFlexibleNumber(String input) {
  var s = input.trim().replaceAll(RegExp(r'[\s %]'), '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    // The last of the two is the decimal mark; the other separates thousands.
    s = lastComma > lastDot ? s.replaceAll('.', '').replaceAll(',', '.') : s.replaceAll(',', '');
  } else if (lastComma >= 0) {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

/// "12/09/2026", "12-9-26", "2026-09-12" (day first, as in Spain).
DateTime? parseFlexibleDate(String input) {
  final s = input.trim().split(RegExp(r'[ T]')).first;
  if (s.isEmpty) return null;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  final dmy = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2}|\d{4})$').firstMatch(s);
  int y, m, d;
  if (iso != null) {
    y = int.parse(iso[1]!);
    m = int.parse(iso[2]!);
    d = int.parse(iso[3]!);
  } else if (dmy != null) {
    d = int.parse(dmy[1]!);
    m = int.parse(dmy[2]!);
    y = int.parse(dmy[3]!);
    if (y < 100) y += 2000;
  } else {
    return null;
  }
  final date = DateTime(y, m, d);
  // Rejects 31/02 and the like (DateTime would roll them over).
  return (date.year == y && date.month == m && date.day == d) ? date : null;
}

/// "17:42", "17:42:05", "9.05" → (hour, minute). Null if not a time.
(int, int)? parseFlexibleTime(String input) {
  final t = RegExp(r'^(\d{1,2})[:.](\d{2})(?:[:.]\d{2})?$').firstMatch(input.trim());
  if (t == null) return null;
  final h = int.parse(t[1]!), m = int.parse(t[2]!);
  return (h < 24 && m < 60) ? (h, m) : null;
}

/// Yes / No in English or Spanish; null if neither.
bool? parseYesNo(String input) {
  switch (input.trim().toLowerCase()) {
    case 'yes' || 'y' || 'si' || 'sí' || 'true' || '1' || 'x':
      return true;
    case 'no' || 'n' || 'false' || '0':
      return false;
  }
  return null;
}
