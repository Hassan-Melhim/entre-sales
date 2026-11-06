import '../import/import_plan.dart';

/// Bringing data in from the old system.
abstract interface class ImportRepository {
  /// Which of these old receipt numbers are already in the store.
  Future<Set<String>> importedReceipts(List<String> receipts);

  /// Adds artists and products (with stock), all or nothing.
  /// Throws [ImportRejectedException] if any name already exists.
  Future<void> importCatalog(List<ArtistDraft> artists, List<ProductDraft> products);

  /// Adds receipts as history (stock is not changed), all or nothing per
  /// call. With [skipExisting], receipts already imported are left out;
  /// otherwise they are refused. Returns how many were added.
  Future<int> importPastSales(List<ReceiptDraft> receipts, {bool skipExisting = false});
}
