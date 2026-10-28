/// One variant as entered in the product form, for saving.
class VariantInput {
  /// Null for a new variant.
  final int? id;
  final Map<String, String> attributes;

  /// The quantity typed in the form.
  final int quantity;

  /// The quantity the form showed when it was opened (0 for a new variant).
  /// Saving adds [quantity] − [quantityBefore], so units sold on another
  /// device while the form was open are not put back.
  final int quantityBefore;

  /// Price before tax, when the product has a price per variant.
  final int? priceOverrideCents;
  final DateTime dateOfArrival;

  const VariantInput({
    this.id,
    this.attributes = const {},
    required this.quantity,
    this.quantityBefore = 0,
    this.priceOverrideCents,
    required this.dateOfArrival,
  });
}
