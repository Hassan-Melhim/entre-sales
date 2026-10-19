import 'dart:convert';

import '../core/dates.dart';

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

  factory Variant.fromMap(Map<String, Object?> m) => Variant(
        id: m['id'] as int,
        productId: m['product_id'] as int,
        attributes: (jsonDecode(m['attributes'] as String? ?? '{}') as Map).map((k, v) => MapEntry('$k', '$v')),
        quantity: m['quantity'] as int,
        priceOverrideCents: m['price_override_cents'] as int?,
        dateOfArrival: fromDb(m['date_of_arrival'] as String),
      );
}
