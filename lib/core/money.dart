import 'package:intl/intl.dart';

/// All money is stored as integer cents to avoid rounding errors.
final NumberFormat _euro = NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2);

String formatCents(int cents) => _euro.format(cents / 100);

/// Accepts "12", "12.5", "12,50". Returns null if not a valid amount.
int? parseEurosToCents(String input) {
  final cleaned = input.trim().replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

/// Cents → "12.50" for pre-filling text fields.
String centsToInput(int cents) => (cents / 100).toStringAsFixed(2);

/// Accepts "21", "21.5", "21,5". Returns null if invalid or outside 0–100.
double? parsePercent(String input) {
  final cleaned = input.trim().replaceAll('%', '').replaceAll(',', '.');
  final value = double.tryParse(cleaned);
  if (value == null || value < 0 || value > 100) return null;
  return value;
}

String formatPercent(double value) {
  final isWhole = value == value.roundToDouble();
  return '${isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}%';
}

/// Rounds half away from zero to whole cents.
int roundCents(double value) => value.round();
