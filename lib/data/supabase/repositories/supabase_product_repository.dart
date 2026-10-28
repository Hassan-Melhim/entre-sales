import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/product.dart';
import '../../../domain/models/product_filter.dart';
import '../../../domain/models/variant_input.dart';
import '../../../domain/repositories/product_repository.dart';
import '../supabase_errors.dart';
import '../supabase_mappers.dart';
import '../supabase_paging.dart';
import '../supabase_values.dart';

class SupabaseProductRepository implements ProductRepository {
  final SupabaseClient _db;
  SupabaseProductRepository(this._db);

  @override
  Future<List<Product>> products([ProductFilter filter = const ProductFilter()]) => guard(() async {
        final rows = await fetchAllPages((from, to) => _db.rpc('search_products', params: {
              'p_query': filter.query.trim(),
              'p_artist_id': filter.artistId,
              'p_category_id': filter.categoryId,
            }).range(from, to));
        final list = rows.map(SupabaseMappers.product).toList();
        list.sort((a, b) {
          if (a.isOutOfStock != b.isOutOfStock) return a.isOutOfStock ? 1 : -1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return list;
      });

  @override
  Future<Product?> product(int id) => guard(() async {
        final row = await _db.from('product_rows').select().eq('id', id).maybeSingle();
        return row == null ? null : SupabaseMappers.product(row);
      });

  /// Saved in one step by the database (save_product).
  @override
  Future<int> save({
    int? id,
    required String name,
    required int artistId,
    required int categoryId,
    required int basePriceCents,
    required bool perVariantPricing,
    required double? taxPercentOverride,
    required double? commissionPercentOverride,
    required List<VariantInput> variants,
  }) =>
      guard(() async {
        final newId = await _db.rpc('save_product', params: {
          'p': {
            'id': id,
            'name': name,
            'artist_id': artistId,
            'category_id': categoryId,
            'base_price_cents': basePriceCents,
            'per_variant_pricing': perVariantPricing,
            'tax_percent_override': taxPercentOverride,
            'commission_percent_override': commissionPercentOverride,
            'variants': [
              for (final v in variants)
                {
                  'id': v.id,
                  'attributes': v.attributes,
                  'quantity': v.quantity,
                  'quantity_before': v.quantityBefore,
                  'price_override_cents': v.priceOverrideCents,
                  'date_of_arrival': dayToDb(v.dateOfArrival),
                },
            ],
          },
        });
        return asInt(newId);
      });

  @override
  Future<void> setCommissionOverride(int productId, double? percent) => guard(
      () => _db.from('products').update({'commission_percent_override': percent}).eq('id', productId));

  @override
  Future<void> restock(int variantId, int addQuantity, DateTime arrival) => guard(() => _db.rpc('restock',
      params: {'p_variant_id': variantId, 'p_quantity': addQuantity, 'p_arrival': dayToDb(arrival)}));

  @override
  Future<bool> canDelete(int id) => guard(() async {
        final sales = await _db.from('order_items').select('id').eq('product_id', id).limit(1);
        return sales.isEmpty;
      });

  @override
  Future<void> delete(int id) => guard(() => _db.from('products').delete().eq('id', id));
}
