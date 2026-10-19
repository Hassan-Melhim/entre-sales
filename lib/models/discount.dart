import '../core/db_values.dart';

/// A discount that can be ticked before completing a sale
/// (e.g. Friends & Family 5%).
class Discount {
  final int? id;
  final String name;
  final double percent;
  final bool active;

  const Discount({this.id, required this.name, required this.percent, this.active = true});

  factory Discount.fromMap(Map<String, Object?> m) => Discount(
        id: m['id'] as int,
        name: m['name'] as String,
        percent: doubleFromDb(m['percent'])!,
        active: boolFromDb(m['active']),
      );

  Map<String, Object?> toMap() => {'name': name, 'percent': percent, 'active': active ? 1 : 0};
}
