/// Search and filters for the product list.
class ProductFilter {
  final String query;
  final int? artistId;
  final int? categoryId;

  const ProductFilter({this.query = '', this.artistId, this.categoryId});

  @override
  bool operator ==(Object other) =>
      other is ProductFilter && other.query == query && other.artistId == artistId && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(query, artistId, categoryId);
}
