import '../models/product.dart';
import '../models/product_filter.dart';
import '../models/variant.dart';

/// Products and their variants (the inventory).
abstract interface class ProductRepository {
  /// In-stock products first, fully out-of-stock products last.
  Future<List<Product>> products([ProductFilter filter = const ProductFilter()]);
  Future<Product?> product(int id);

  /// Creates or updates a product. [variants] is the full list: variants
  /// with an id are updated, new ones added, and missing ones removed
  /// (or set to 0 if they were ever sold). Returns the product id.
  Future<int> save({
    int? id,
    required String name,
    required int artistId,
    required int categoryId,
    required int basePriceCents,
    required bool perVariantPricing,
    required double? taxPercentOverride,
    required double? commissionPercentOverride,
    required List<Variant> variants,
  });

  /// Sets this product's own commission; null = use the artist's.
  Future<void> setCommissionOverride(int productId, double? percent);

  /// Adds stock to a variant. A restock overwrites the date of arrival.
  Future<void> restock(int variantId, int addQuantity, DateTime arrival);

  /// False when the product has sales (it is kept for history).
  Future<bool> canDelete(int id);
  Future<void> delete(int id);
}
