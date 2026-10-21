import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/dates.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/repositories/artist_repository.dart';
import '../db_values.dart';
import '../sqlite_mappers.dart';

class SqliteArtistRepository implements ArtistRepository {
  final Database _db;
  SqliteArtistRepository(this._db);

  @override
  Future<List<Artist>> artists() async {
    final rows = await _db.query('artists', orderBy: 'name COLLATE NOCASE');
    return rows.map(SqliteMappers.artist).toList();
  }

  @override
  Future<Artist?> artist(int id) async {
    final rows = await _db.query('artists', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SqliteMappers.artist(rows.first);
  }

  @override
  Future<int> save(Artist a) async {
    final row = SqliteMappers.artistRow(a);
    if (a.id == null) return _db.insert('artists', {...row, 'created_at': toDb(DateTime.now())});
    await _db.update('artists', row, where: 'id = ?', whereArgs: [a.id]);
    return a.id!;
  }

  @override
  Future<void> setCommission(int artistId, double? percent) =>
      _db.update('artists', {'commission_percent': percent}, where: 'id = ?', whereArgs: [artistId]);

  @override
  Future<bool> canDelete(int id) async {
    final products = firstInt(await _db.rawQuery('SELECT COUNT(*) FROM products WHERE artist_id = ?', [id]));
    final sales = firstInt(await _db.rawQuery('SELECT COUNT(*) FROM order_items WHERE artist_id = ?', [id]));
    return products == 0 && sales == 0;
  }

  @override
  Future<void> delete(int id) => _db.delete('artists', where: 'id = ?', whereArgs: [id]);
}
