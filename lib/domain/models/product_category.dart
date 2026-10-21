import 'category_attribute.dart';

/// A product category (Clothing, Books & Zines, …) with its VAT rate and fields.
///
/// Named ProductCategory because Flutter already has a `Category` annotation.
class ProductCategory {
  final int? id;
  final String name;
  final double taxPercent;
  final List<CategoryAttribute> attributes;

  const ProductCategory({this.id, required this.name, required this.taxPercent, this.attributes = const []});
}
