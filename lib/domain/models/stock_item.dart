/// Units of a variant currently on display (for shelf-life analysis).
class StockItem {
  final int productId;
  final String productName;
  final String artistName;
  final String categoryName;
  final int quantity;
  final DateTime arrival;

  // Prices and rates a sale would use now, to value the stock. Null when the
  // database hasn't been updated yet (migration 20261122120000).
  final int? artistId;
  final bool artistResident;
  final int? unitBaseCents;
  final double? taxPercent;
  final double? commissionPercent;

  const StockItem({
    required this.productId,
    required this.productName,
    required this.artistName,
    required this.categoryName,
    required this.quantity,
    required this.arrival,
    this.artistId,
    this.artistResident = false,
    this.unitBaseCents,
    this.taxPercent,
    this.commissionPercent,
  });

  bool get hasPrices => unitBaseCents != null && taxPercent != null && commissionPercent != null;
}
