/// How quickly a category's stock is moving.
class CategoryTurnover {
  final String category;
  final int soldUnits;
  final int inStockUnits;
  final double? avgDaysToSell;

  const CategoryTurnover(this.category, this.soldUnits, this.inStockUnits, this.avgDaysToSell);

  /// Share of available units that sold in the period.
  double get sellThrough => (soldUnits + inStockUnits) == 0 ? 0 : soldUnits / (soldUnits + inStockUnits);
}
