import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/import/import_plan.dart';
import '../../../domain/repositories/import_repository.dart';
import '../supabase_errors.dart';
import '../supabase_values.dart';

/// Uses the import_catalog / import_past_sales database functions
/// (supabase/migrations/20261106120000_import_and_logos.sql).
class SupabaseImportRepository implements ImportRepository {
  final SupabaseClient _db;
  SupabaseImportRepository(this._db);

  @override
  Future<Set<String>> importedReceipts(List<String> receipts) => guard(() async {
        if (receipts.isEmpty) return <String>{};
        final found = <String>{};
        // In chunks, to keep each request small.
        for (var i = 0; i < receipts.length; i += 1000) {
          final chunk = receipts.sublist(i, (i + 1000).clamp(0, receipts.length));
          final rows = await _db.rpc('imported_receipts', params: {'p_receipts': chunk});
          found.addAll((rows as List).map((r) => r is Map ? '${r.values.first}' : '$r'));
        }
        return found;
      });

  @override
  Future<void> importCatalog(List<ArtistDraft> artists, List<ProductDraft> products) =>
      guard(() => _db.rpc('import_catalog', params: {
            'p': {
              'artists': [
                for (final a in artists)
                  {
                    'name': a.name,
                    'is_spain_resident': a.isSpainResident,
                    'commission_percent': a.commissionPercent,
                    'gender': a.gender,
                    'legal_name': a.legalName,
                    'tax_id': a.taxId,
                    'address': a.address,
                    'iban': a.iban,
                    'bank_name': a.bankName,
                  },
              ],
              'products': [
                for (final p in products)
                  {
                    'artist': p.artistName,
                    'name': p.name,
                    'category': p.categoryName,
                    'base_price_cents': p.basePriceCents,
                    'per_variant_pricing': p.perVariantPricing,
                    'tax_percent_override': p.taxPercentOverride,
                    'commission_percent_override': p.commissionPercentOverride,
                    'variants': [
                      for (final v in p.variants)
                        {
                          'attributes': v.attributes,
                          'quantity': v.quantity,
                          'price_override_cents': v.priceOverrideCents,
                          'date_of_arrival': dayToDb(v.dateOfArrival),
                        },
                    ],
                  },
              ],
            },
          }));

  @override
  Future<int> importPastSales(List<ReceiptDraft> receipts, {bool skipExisting = false}) => guard(() async {
        final added = await _db.rpc('import_past_sales', params: {
          'p_receipts': [
            for (final r in receipts)
              {
                'receipt': r.receipt,
                // Store (Madrid) wall-clock time; the database converts it.
                'at': '${dayToDb(r.at)} ${_two(r.at.hour)}:${_two(r.at.minute)}:00',
                'payment': r.paymentMethod,
                'discount': r.discountName,
                'lines': [
                  for (final l in r.lines)
                    {
                      'artist': l.artistName,
                      'product': l.productName,
                      'category': l.categoryName,
                      'variant': l.variant,
                      'quantity': l.quantity,
                      'base_cents': l.baseCents,
                      'total_cents': l.totalCents,
                      'commission_percent': l.commissionPercent,
                    },
                ],
              },
          ],
          'p_skip_existing': skipExisting,
        });
        return asInt(added);
      });

  static String _two(int n) => n.toString().padLeft(2, '0');
}
