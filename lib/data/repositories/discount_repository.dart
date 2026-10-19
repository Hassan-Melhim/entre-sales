import 'package:sqflite/sqflite.dart';

import '../../models/discount.dart';

class DiscountRepository {
  final Database db;
  DiscountRepository(this.db);

  Future<List<Discount>> discounts({bool activeOnly = false}) async {
    final rows = await db.query('discounts', where: activeOnly ? 'active = 1' : null, orderBy: 'name COLLATE NOCASE');
    return rows.map(Discount.fromMap).toList();
  }

  Future<void> save(Discount d) async {
    final data = d.toMap();
    if (d.id == null) {
      await db.insert('discounts', data);
    } else {
      await db.update('discounts', data, where: 'id = ?', whereArgs: [d.id]);
    }
  }
}
