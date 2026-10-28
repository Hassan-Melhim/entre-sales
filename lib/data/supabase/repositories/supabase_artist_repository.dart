import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/artist.dart';
import '../../../domain/repositories/artist_repository.dart';
import '../supabase_errors.dart';
import '../supabase_mappers.dart';
import '../supabase_values.dart';

class SupabaseArtistRepository implements ArtistRepository {
  final SupabaseClient _db;
  SupabaseArtistRepository(this._db);

  @override
  Future<List<Artist>> artists() => guard(() async {
        final rows = asRows(await _db.from('artists').select());
        return rows.map(SupabaseMappers.artist).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });

  @override
  Future<Artist?> artist(int id) => guard(() async {
        final row = await _db.from('artists').select().eq('id', id).maybeSingle();
        return row == null ? null : SupabaseMappers.artist(row);
      });

  @override
  Future<int> save(Artist a) => guard(() async {
        final row = SupabaseMappers.artistRow(a);
        if (a.id == null) {
          final created = await _db.from('artists').insert(row).select('id').single();
          return asInt(created['id']);
        }
        await _db.from('artists').update(row).eq('id', a.id!);
        return a.id!;
      });

  @override
  Future<void> setCommission(int artistId, double? percent) =>
      guard(() => _db.from('artists').update({'commission_percent': percent}).eq('id', artistId));

  @override
  Future<bool> canDelete(int id) => guard(() async {
        final products = await _db.from('products').select('id').eq('artist_id', id).limit(1);
        final sales = await _db.from('order_items').select('id').eq('artist_id', id).limit(1);
        return products.isEmpty && sales.isEmpty;
      });

  @override
  Future<void> delete(int id) => guard(() => _db.from('artists').delete().eq('id', id));
}
