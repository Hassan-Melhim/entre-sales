/// Units of a variant currently on display (for shelf-life analysis).
class StockItem {
  final int productId;
  final String productName;
  final String artistName;
  final String categoryName;
  final int quantity;
  final DateTime arrival;

  const StockItem({
    required this.productId,
    required this.productName,
    required this.artistName,
    required this.categoryName,
    required this.quantity,
    required this.arrival,
  });
}
