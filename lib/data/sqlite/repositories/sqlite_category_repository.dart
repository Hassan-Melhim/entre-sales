import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../domain/models/product_category.dart';
import '../../../domain/repositories/category_repository.dart';
import '../db_values.dart';
import '../sqlite_mappers.dart';

class SqliteCategoryRepository implements CategoryRepository {
  final Database _db;
  SqliteCategoryRepository(this._db);

  @override
  Future<List<ProductCategory>> categories() async {
    final cats = await _db.query('categories', orderBy: 'sort_order, name COLLATE NOCASE');
    final attrs = await _db.query('category_attributes', orderBy: 'sort_order, id');
    return [
      for (final c in cats)
        SqliteMappers.category(
            c, attrs.where((a) => a['category_id'] == c['id']).map(SqliteMappers.attribute).toList()),
    ];
  }

  /// Existing products keep their variant values even if a field is renamed.
  @override
  Future<int> save(ProductCategory c) {
    return _db.transaction((txn) async {
      int id;
      if (c.id == null) {
        final maxOrder = firstInt(await txn.rawQuery('SELECT COALESCE(MAX(sort_order), 0) FROM categories'));
        id = await txn.insert('categories', {'name': c.name, 'tax_percent': c.taxPercent, 'sort_order': maxOrder + 1});
      } else {
        id = c.id!;
        await txn.update('categories', {'name': c.name, 'tax_percent': c.taxPercent},
            where: 'id = ?', whereArgs: [id]);
        await txn.delete('category_attributes', where: 'category_id = ?', whereArgs: [id]);
      }
      var order = 0;
      for (final a in c.attributes) {
        await txn.insert('category_attributes', {
          'category_id': id,
          'name': a.name,
          'options': jsonEncode(a.options),
          'sort_order': order++,
        });
      }
      return id;
    });
  }

  @override
  Future<bool> canDelete(int id) async =>
      firstInt(await _db.rawQuery('SELECT COUNT(*) FROM products WHERE category_id = ?', [id])) == 0;

  @override
  Future<void> delete(int id) => _db.delete('categories', where: 'id = ?', whereArgs: [id]);
}
