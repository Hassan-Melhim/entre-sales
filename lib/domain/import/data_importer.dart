import '../repositories/import_repository.dart';
import 'import_plan.dart';

/// Runs a checked [ImportPlan]: artists and products first (in one step),
/// then the past sales in batches, reporting progress from 0 to 1.
///
/// Each batch is saved completely or not at all, and an old receipt number
/// can only be imported once, so an interrupted import can safely be run
/// again with "skip receipts already imported".
class DataImporter {
  static const receiptsPerBatch = 250;

  final ImportRepository _repo;
  DataImporter(this._repo);

  Future<ImportSummary> run(ImportPlan plan, {bool skipExisting = false, void Function(double)? onProgress}) async {
    onProgress?.call(0);
    if (plan.artists.isNotEmpty || plan.products.isNotEmpty) {
      await _repo.importCatalog(plan.artists, plan.products);
    }
    final total = plan.receipts.length;
    var added = 0;
    onProgress?.call(total == 0 ? 1 : 0.05);
    for (var i = 0; i < total; i += receiptsPerBatch) {
      final batch = plan.receipts.sublist(i, (i + receiptsPerBatch).clamp(0, total));
      added += await _repo.importPastSales(batch, skipExisting: skipExisting);
      onProgress?.call(0.05 + 0.95 * (i + batch.length) / total);
    }
    return ImportSummary(
      artists: plan.artists.length,
      products: plan.products.length,
      variants: plan.variantCount,
      receipts: added,
      skippedReceipts: total - added,
    );
  }
}

class ImportSummary {
  final int artists, products, variants, receipts, skippedReceipts;
  const ImportSummary({
    required this.artists,
    required this.products,
    required this.variants,
    required this.receipts,
    required this.skippedReceipts,
  });

  @override
  String toString() => [
        if (artists > 0) '$artists artists',
        if (products > 0) '$products products ($variants variants)',
        if (receipts > 0) '$receipts past receipts',
        if (skippedReceipts > 0) '$skippedReceipts receipts skipped (already imported)',
      ].join(', ');
}
