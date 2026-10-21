import '../models/product_category.dart';

/// Product categories with their VAT rate and fields.
abstract interface class CategoryRepository {
  Future<List<ProductCategory>> categories();

  /// Creates or updates a category and replaces its fields. Returns its id.
  Future<int> save(ProductCategory category);

  /// False when products use the category.
  Future<bool> canDelete(int id);
  Future<void> delete(int id);
}
