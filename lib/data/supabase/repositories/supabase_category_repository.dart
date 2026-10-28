import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/product_category.dart';
import '../../../domain/repositories/category_repository.dart';
import '../supabase_errors.dart';
import '../supabase_mappers.dart';
import '../supabase_values.dart';

class SupabaseCategoryRepository implements CategoryRepository {
  final SupabaseClient _db;
  SupabaseCategoryRepository(this._db);

  @override
  Future<List<ProductCategory>> categories() => guard(() async {
        final rows = asRows(await _db.from('categories').select('*, category_attributes(*)'));
        rows.sort((a, b) {
          final byOrder = asInt(a['sort_order']).compareTo(asInt(b['sort_order']));
          return byOrder != 0
              ? byOrder
              : (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
        });
        return rows.map(SupabaseMappers.category).toList();
      });

  /// Saved in one step by the database (save_category), fields included.
  @override
  Future<int> save(ProductCategory c) => guard(() async {
        final id = await _db.rpc('save_category', params: {
          'c': {
            'id': c.id,
            'name': c.name,
            'tax_percent': c.taxPercent,
            'attributes': [
              for (final a in c.attributes) {'name': a.name, 'options': a.options},
            ],
          },
        });
        return asInt(id);
      });

  @override
  Future<bool> canDelete(int id) => guard(() async {
        final products = await _db.from('products').select('id').eq('category_id', id).limit(1);
        return products.isEmpty;
      });

  @override
  Future<void> delete(int id) => guard(() => _db.from('categories').delete().eq('id', id));
}
