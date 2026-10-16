import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../config/business_rules.dart';
import '../../core/dates.dart';
import '../models.dart';

/// Artists, categories, products and variants.
class InventoryRepository {
  final Database db;
  InventoryRepository(this.db);

  // ---------------------------------------------------------------- Artists

  Future<List<Artist>> artists() async {
    final rows = await db.query('artists', orderBy: 'name COLLATE NOCASE');
    return rows.map(Artist.fromMap).toList();
  }

  Future<Artist?> artist(int id) async {
    final rows = await db.query('artists', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Artist.fromMap(rows.first);
  }

  Future<int> saveArtist(Artist a) async {
    if (a.id == null) {
      return db.insert('artists', {...a.toMap(), 'created_at': toDb(DateTime.now())});
    }
    await db.update('artists', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    return a.id!;
  }

  /// Artists with products or sales cannot be deleted (it would break history).
  Future<bool> canDeleteArtist(int id) async {
    final p = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products WHERE artist_id = ?', [id]));
    final s = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM order_items WHERE artist_id = ?', [id]));
    return (p ?? 0) == 0 && (s ?? 0) == 0;
  }

  Future<void> deleteArtist(int id) => db.delete('artists', where: 'id = ?', whereArgs: [id]);

  // ------------------------------------------------------------- Categories

  Future<List<ProductCategory>> categories() async {
    final cats = await db.query('categories', orderBy: 'sort_order, name COLLATE NOCASE');
    final attrs = await db.query('category_attributes', orderBy: 'sort_order, id');
    return cats.map((c) {
      final own = attrs.where((a) => a['category_id'] == c['id']).map(CategoryAttribute.fromMap).toList();
      return ProductCategory.fromMap(c, own);
    }).toList();
  }

  /// Creates or updates a category and replaces its attribute list.
  /// Existing products keep their variant values even if an attribute is renamed.
  Future<int> saveCategory(ProductCategory c) async {
    return db.transaction((txn) async {
      int id;
      if (c.id == null) {
        final maxOrder =
            Sqflite.firstIntValue(await txn.rawQuery('SELECT COALESCE(MAX(sort_order), 0) FROM categories')) ?? 0;
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

  Future<bool> canDeleteCategory(int id) async {
    final n = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products WHERE category_id = ?', [id]));
    return (n ?? 0) == 0;
  }

  Future<void> deleteCategory(int id) => db.delete('categories', where: 'id = ?', whereArgs: [id]);

  // --------------------------------------------------------------- Products

  /// All products with their variants.
  /// In-stock products come first; fully out-of-stock products go last.
  /// [query] matches product name or artist name.
  Future<List<Product>> products({String query = '', int? artistId, int? categoryId}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(p.name LIKE ? OR a.name LIKE ?)');
      final like = '%${query.trim()}%';
      args.addAll([like, like]);
    }
    if (artistId != null) {
      where.add('p.artist_id = ?');
      args.add(artistId);
    }
    if (categoryId != null) {
      where.add('p.category_id = ?');
      args.add(categoryId);
    }
    final rows = await db.rawQuery('''
      SELECT p.*, a.name AS artist_name, a.commission_percent AS artist_commission,
             c.name AS category_name, c.tax_percent AS category_tax
      FROM products p
      JOIN artists a ON a.id = p.artist_id
      JOIN categories c ON c.id = p.category_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY p.name COLLATE NOCASE
    ''', args);
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id']).toList();
    final variantRows = await db.query(
      'variants',
      where: 'product_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'id',
    );
    final byProduct = <int, List<Variant>>{};
    for (final v in variantRows) {
      byProduct.putIfAbsent(v['product_id'] as int, () => []).add(Variant.fromMap(v));
    }

    final list = rows.map((r) => _productFromRow(r, byProduct[r['id']] ?? [])).toList();
    list.sort((a, b) {
      if (a.isOutOfStock != b.isOutOfStock) return a.isOutOfStock ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<Product?> product(int id) async {
    final rows = await db.rawQuery('''
      SELECT p.*, a.name AS artist_name, a.commission_percent AS artist_commission,
             c.name AS category_name, c.tax_percent AS category_tax
      FROM products p
      JOIN artists a ON a.id = p.artist_id
      JOIN categories c ON c.id = p.category_id
      WHERE p.id = ?''', [id]);
    if (rows.isEmpty) return null;
    final variants = await db.query('variants', where: 'product_id = ?', whereArgs: [id], orderBy: 'id');
    return _productFromRow(rows.first, variants.map(Variant.fromMap).toList());
  }

  Product _productFromRow(Map<String, Object?> r, List<Variant> variants) {
    final commission = r['artist_commission'] == null
        ? BusinessRules.defaultCommissionPercent
        : (r['artist_commission'] as num).toDouble();
    return Product(
      id: r['id'] as int,
      name: r['name'] as String,
      artistId: r['artist_id'] as int,
      artistName: r['artist_name'] as String,
      categoryId: r['category_id'] as int,
      categoryName: r['category_name'] as String,
      categoryTaxPercent: (r['category_tax'] as num).toDouble(),
      basePriceCents: r['base_price_cents'] as int,
      perVariantPricing: r['per_variant_pricing'] == 1,
      taxPercentOverride: r['tax_percent_override'] == null ? null : (r['tax_percent_override'] as num).toDouble(),
      artistCommissionPercent: commission,
      variants: variants,
    );
  }

  /// Creates or updates a product.
  ///
  /// [variants] is the full list: variants with an id are updated, new ones
  /// inserted, and existing variants missing from the list are deleted
  /// (only if they were never sold; otherwise their stock is set to 0).
  Future<int> saveProduct({
    int? id,
    required String name,
    required int artistId,
    required int categoryId,
    required int basePriceCents,
    required bool perVariantPricing,
    required double? taxPercentOverride,
    required List<Variant> variants,
  }) async {
    return db.transaction((txn) async {
      final data = {
        'name': name,
        'artist_id': artistId,
        'category_id': categoryId,
        'base_price_cents': basePriceCents,
        'per_variant_pricing': perVariantPricing ? 1 : 0,
        'tax_percent_override': taxPercentOverride,
      };
      int productId;
      if (id == null) {
        productId = await txn.insert('products', {...data, 'created_at': toDb(DateTime.now())});
      } else {
        productId = id;
        await txn.update('products', data, where: 'id = ?', whereArgs: [id]);
      }

      final existing = await txn.query('variants', columns: ['id'], where: 'product_id = ?', whereArgs: [productId]);
      final keptIds = variants.where((v) => v.id != null).map((v) => v.id).toSet();
      for (final row in existing) {
        final vid = row['id'] as int;
        if (keptIds.contains(vid)) continue;
        final sold = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM order_items WHERE variant_id = ?', [vid])) ??
            0;
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

  /// Adds stock to a variant. A restock overwrites the date of arrival.
  Future<void> restock(int variantId, int addQuantity, DateTime arrival) async {
    await db.rawUpdate(
      'UPDATE variants SET quantity = quantity + ?, date_of_arrival = ? WHERE id = ?',
      [addQuantity, toDb(arrival), variantId],
    );
  }

  Future<bool> canDeleteProduct(int id) async {
    final n = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM order_items WHERE product_id = ?', [id]));
    return (n ?? 0) == 0;
  }

  Future<void> deleteProduct(int id) => db.delete('products', where: 'id = ?', whereArgs: [id]);
}
