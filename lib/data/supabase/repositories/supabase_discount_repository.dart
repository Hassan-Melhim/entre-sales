import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/discount.dart';
import '../../../domain/repositories/discount_repository.dart';
import '../supabase_errors.dart';
import '../supabase_mappers.dart';
import '../supabase_values.dart';

class SupabaseDiscountRepository implements DiscountRepository {
  final SupabaseClient _db;
  SupabaseDiscountRepository(this._db);

  @override
  Future<List<Discount>> discounts({bool activeOnly = false}) => guard(() async {
        var query = _db.from('discounts').select();
        if (activeOnly) query = query.eq('active', true);
        final rows = asRows(await query);
        return rows.map(SupabaseMappers.discount).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });

  @override
  Future<void> save(Discount d) => guard(() async {
        final row = SupabaseMappers.discountRow(d);
        if (d.id == null) {
          await _db.from('discounts').insert(row);
        } else {
          await _db.from('discounts').update(row).eq('id', d.id!);
        }
      });
}
