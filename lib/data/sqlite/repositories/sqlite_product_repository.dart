import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/dates.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_filter.dart';
import '../../../domain/models/variant.dart';
import '../../../domain/repositories/product_repository.dart';
import '../db_values.dart';
import '../sqlite_mappers.dart';

class SqliteProductRepository implements ProductRepository {
  final Database _db;
  SqliteProductRepository(this._db);

  static const _select = '''
    SELECT p.*, a.name AS artist_name, a.commission_percent AS artist_commission,
           c.name AS category_name, c.tax_percent AS category_tax
    FROM products p
    JOIN artists a ON a.id = p.artist_id
    JOIN categories c ON c.id = p.category_id''';

  @override
  Future<List<Product>> products([ProductFilter filter = const ProductFilter()]) async {
    final where = <String>[];
    final args = <Object?>[];
    if (filter.query.trim().isNotEmpty) {
      where.add('(p.name LIKE ? OR a.name LIKE ?)');
      final like = '%${filter.query.trim()}%';
      args.addAll([like, like]);
    }
    if (filter.artistId != null) {
      where.add('p.artist_id = ?');
      args.add(filter.artistId);
    }
    if (filter.categoryId != null) {
      where.add('p.category_id = ?');
      args.add(filter.categoryId);
    }
    final rows = await _db.rawQuery(
        '$_select ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY p.name COLLATE NOCASE', args);
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id']).toList();
    final variantRows = await _db.query('variants',
        where: 'product_id IN (${placeholders(ids.length)})', whereArgs: ids, orderBy: 'id');
    final byProduct = <int, List<Variant>>{};
    for (final v in variantRows) {
      byProduct.putIfAbsent(v['product_id'] as int, () => []).add(SqliteMappers.variant(v));
    }

    final list = [for (final r in rows) SqliteMappers.product(r, byProduct[r['id']] ?? [])];
    list.sort((a, b) {
      if (a.isOutOfStock != b.isOutOfStock) return a.isOutOfStock ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  Future<Product?> product(int id) async {
    final rows = await _db.rawQuery('$_select WHERE p.id = ?', [id]);
    if (rows.isEmpty) return null;
    final variants = await _db.query('variants', where: 'product_id = ?', whereArgs: [id], orderBy: 'id');
    return SqliteMappers.product(rows.first, variants.map(SqliteMappers.variant).toList());
  }

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
    required List<Variant> variants,
  }) {
    return _db.transaction((txn) async {
      final data = {
        'name': name,
        'artist_id': artistId,
        'category_id': categoryId,
        'base_price_cents': basePriceCents,
        'per_variant_pricing': perVariantPricing ? 1 : 0,
        'tax_percent_override': taxPercentOverride,
        'commission_percent_override': commissionPercentOverride,
      };
      int productId;
      if (id == null) {
        productId = await txn.insert('products', {...data, 'created_at': toDb(DateTime.now())});
      } else {
        productId = id;
        await txn.update('products', data, where: 'id = ?', whereArgs: [id]);
      }

      // Variants removed from the form: delete if never sold, else set to 0.
      final existing = await txn.query('variants', columns: ['id'], where: 'product_id = ?', whereArgs: [productId]);
      final keptIds = variants.where((v) => v.id != null).map((v) => v.id).toSet();
      for (final row in existing) {
        final vid = row['id'] as int;
        if (keptIds.contains(vid)) continue;
        final sold = firstInt(await txn.rawQuery('SELECT COUNT(*) FROM order_items WHERE variant_id = ?', [vid]));
        if (sold == 0) {
          await txn.delete('variants', where: 'id = ?', whereArgs: [vid]);
        } else {
          await txn.update('variants', {'quantity': 0}, where: 'id = ?', whereArgs: [vid]);
        }
      }

      for (final v in variants) {
        final vData = {
          'product_id': productId,
          'attributes': jsonEncode(v.attributes),
          'quantity': v.quantity,
          'price_override_cents': perVariantPricing ? v.priceOverrideCents : null,
          'date_of_arrival': toDb(v.dateOfArrival),
        };
        if (v.id == null) {
          await txn.insert('variants', vData);
        } else {
          await txn.update('variants', vData, where: 'id = ?', whereArgs: [v.id]);
        }
      }
      return productId;
    });
  }

  @override
  Future<void> setCommissionOverride(int productId, double? percent) =>
      _db.update('products', {'commission_percent_override': percent}, where: 'id = ?', whereArgs: [productId]);

  @override
  Future<void> restock(int variantId, int addQuantity, DateTime arrival) => restockWith(_db, variantId, addQuantity, arrival);

  /// [restock] on a given executor (used inside the demo-data transaction).
  static Future<void> restockWith(DatabaseExecutor ex, int variantId, int addQuantity, DateTime arrival) =>
      ex.rawUpdate('UPDATE variants SET quantity = quantity + ?, date_of_arrival = ? WHERE id = ?',
          [addQuantity, toDb(arrival), variantId]);

  @override
  Future<bool> canDelete(int id) async =>
      firstInt(await _db.rawQuery('SELECT COUNT(*) FROM order_items WHERE product_id = ?', [id])) == 0;

  @override
  Future<void> delete(int id) => _db.delete('products', where: 'id = ?', whereArgs: [id]);
}
