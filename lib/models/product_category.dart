import '../core/db_values.dart';
import 'category_attribute.dart';

/// A product category (Clothes, Books, …) with its VAT rate and fields.
///
/// Named ProductCategory because Flutter already has a `Category` annotation.
class ProductCategory {
  final int? id;
  final String name;
  final double taxPercent;
  final List<CategoryAttribute> attributes;

  const ProductCategory({this.id, required this.name, required this.taxPercent, this.attributes = const []});

  factory ProductCategory.fromMap(Map<String, Object?> m, List<CategoryAttribute> attributes) => ProductCategory(
        id: m['id'] as int,
        name: m['name'] as String,
        taxPercent: doubleFromDb(m['tax_percent'])!,
        attributes: attributes,
      );
}
