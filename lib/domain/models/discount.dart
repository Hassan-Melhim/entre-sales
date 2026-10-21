/// A discount that can be ticked before completing a sale
/// (e.g. Friends & Family 5%).
class Discount {
  final int? id;
  final String name;
  final double percent;
  final bool active;

  const Discount({this.id, required this.name, required this.percent, this.active = true});

  Discount copyWith({bool? active}) => Discount(id: id, name: name, percent: percent, active: active ?? this.active);
}
