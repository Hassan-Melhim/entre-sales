/// One sellable version of a product, e.g. the M size of a shirt.
class Variant {
  final int? id;
  final int? productId;

  /// e.g. {"Size": "M", "Colour": "Black"}. Empty for products without fields.
  final Map<String, String> attributes;
  final int quantity;

  /// Price before tax; only used when the product has per-variant pricing.
  final int? priceOverrideCents;

  /// Overwritten on every restock.
  final DateTime dateOfArrival;

  const Variant({
    this.id,
    this.productId,
    this.attributes = const {},
    required this.quantity,
    this.priceOverrideCents,
    required this.dateOfArrival,
  });

  String get label => labelFor(attributes);

  static String labelFor(Map<String, String> attributes) =>
      attributes.isEmpty ? 'Standard' : attributes.values.join(' · ');
}
