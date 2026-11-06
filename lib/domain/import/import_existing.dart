import '../models/product_category.dart';

/// What is already in the store, to check the files against.
class ImportExisting {
  /// Lower-case artist names.
  final Set<String> artistNames;

  /// "artist|product", lower case.
  final Set<String> productKeys;
  final List<ProductCategory> categories;

  /// Discount names as written in the app.
  final List<String> discountNames;

  /// Old receipt numbers already imported.
  final Set<String> importedReceipts;

  const ImportExisting({
    this.artistNames = const {},
    this.productKeys = const {},
    this.categories = const [],
    this.discountNames = const [],
    this.importedReceipts = const {},
  });

  static String productKey(String artist, String product) => '${artist.trim().toLowerCase()}|${product.trim().toLowerCase()}';
}
