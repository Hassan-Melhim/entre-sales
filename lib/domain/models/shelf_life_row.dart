/// How long a product stayed (or has stayed) on display.
class ShelfLifeRow {
  final String productName;
  final String artistName;
  final String categoryName;

  /// Average days from arrival to sale, or days since arrival for unsold stock.
  final double days;
  final int units;

  const ShelfLifeRow(this.productName, this.artistName, this.categoryName, this.days, this.units);
}
