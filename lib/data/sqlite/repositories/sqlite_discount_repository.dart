import 'package:sqflite_common/sqlite_api.dart';

import '../../../domain/models/discount.dart';
import '../../../domain/repositories/discount_repository.dart';
import '../sqlite_mappers.dart';

class SqliteDiscountRepository implements DiscountRepository {
  final Database _db;
  SqliteDiscountRepository(this._db);

  @override
  Future<List<Discount>> discounts({bool activeOnly = false}) async {
    final rows = await _db.query('discounts', where: activeOnly ? 'active = 1' : null, orderBy: 'name COLLATE NOCASE');
    return rows.map(SqliteMappers.discount).toList();
  }

  @override
  Future<void> save(Discount d) async {
    final row = SqliteMappers.discountRow(d);
    if (d.id == null) {
      await _db.insert('discounts', row);
    } else {
      await _db.update('discounts', row, where: 'id = ?', whereArgs: [d.id]);
    }
  }
}
