import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/dates.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/calendar_session.dart';
import '../../../domain/models/cart_line.dart';
import '../../../domain/models/category_attribute.dart';
import '../../../domain/models/demo_load_result.dart';
import '../../../domain/models/discount.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_category.dart';
import '../../../domain/models/variant.dart';
import '../../../domain/repositories/data_admin_repository.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../app_database.dart';
import '../database_platform.dart';
import 'sqlite_artist_repository.dart';
import 'sqlite_category_repository.dart';
import 'sqlite_discount_repository.dart';
import 'sqlite_product_repository.dart';
import 'sqlite_sales_repository.dart';
import 'sqlite_session_repository.dart';
import 'sqlite_settings_repository.dart';

/// Demo data and backups for the SQLite database.
///
/// The demo history is replayed through the same sale / refund code the
/// shop uses, so every amount, payout and stock level is calculated exactly
/// as for real sales.
class SqliteDataAdminRepository implements DataAdminRepository {
  final Database _db;
  SqliteDataAdminRepository(this._db);

  /// Tables emptied before loading, children first.
  static const _tables = [
    'refunds',
    'order_items',
    'orders',
    'calendar_events',
    'variants',
    'products',
    'category_attributes',
    'categories',
    'artists',
    'discounts',
  ];

  /// Deletes all shop data (settings such as the theme are kept).
  Future<void> wipe() async {
    await _db.transaction((txn) async {
      for (final t in _tables) {
        await txn.delete(t);
      }
      // Start ids from 1 again so order numbers look natural.
      await txn.execute('DELETE FROM sqlite_sequence');
    });
  }

  @override
  Future<List<int>?> exportBackup() async => readDatabaseFile(await AppDatabase.databaseFilePath());

  @override
  Future<DemoLoadResult> loadDemoData(String json, {void Function(double progress)? onProgress}) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final artistsRepo = SqliteArtistRepository(_db);
    final categoriesRepo = SqliteCategoryRepository(_db);
    final productsRepo = SqliteProductRepository(_db);
    final sessionsRepo = SqliteSessionRepository(_db);
    final discountsRepo = SqliteDiscountRepository(_db);

    onProgress?.call(0);
    await wipe();
    await SqliteSettingsRepository(_db).set(SettingKeys.storeName, (data['store'] as Map)['name'] as String);

    // ----------------------------------------------------------- catalog
    final categoryIds = <String, int>{};
    for (final c in (data['categories'] as List).cast<Map<String, dynamic>>()) {
      final attrs = [
        for (final a in (c['attributes'] as List).cast<Map<String, dynamic>>())
          CategoryAttribute(name: a['name'] as String, options: (a['options'] as List).cast<String>()),
      ];
      final name = c['name'] as String;
      categoryIds[name] = await categoriesRepo
          .save(ProductCategory(name: name, taxPercent: (c['tax'] as num).toDouble(), attributes: attrs));
    }

    for (final d in (data['discounts'] as List).cast<Map<String, dynamic>>()) {
      await discountsRepo.save(Discount(name: d['name'] as String, percent: (d['percent'] as num).toDouble()));
    }
    final discounts = {for (final d in await discountsRepo.discounts()) d.name: d};

    final artistIds = <String, int>{};
    for (final a in (data['artists'] as List).cast<Map<String, dynamic>>()) {
      final name = a['name'] as String;
      artistIds[name] = await artistsRepo.save(Artist(
        name: name,
        gender: a['gender'] as String?,
        address: a['address'] as String?,
        legalName: a['legal_name'] as String?,
        taxId: a['tax_id'] as String?,
        iban: a['iban'] as String?,
        bankName: a['bank_name'] as String?,
        isSpainResident: a['resident'] as bool,
        commissionPercent: (a['commission'] as num?)?.toDouble(),
      ));
    }
    onProgress?.call(0.05);

    final productIds = <int>[];
    for (final p in (data['products'] as List).cast<Map<String, dynamic>>()) {
      final variants = [
        for (final v in (p['variants'] as List).cast<Map<String, dynamic>>())
          Variant(
            attributes: (v['attrs'] as Map).map((k, val) => MapEntry('$k', '$val')),
            quantity: v['qty'] as int,
            priceOverrideCents: v['price'] as int?,
            dateOfArrival: fromDb(v['arrival'] as String),
          ),
      ];
      productIds.add(await productsRepo.save(
        name: p['name'] as String,
        artistId: artistIds[p['artist']]!,
        categoryId: categoryIds[p['category']]!,
        basePriceCents: p['base'] as int,
        perVariantPricing: p['per_variant'] as bool,
        taxPercentOverride: (p['tax_override'] as num?)?.toDouble(),
        commissionPercentOverride: (p['commission_override'] as num?)?.toDouble(),
        variants: variants,
      ));
    }
    // Reload with artist / category details; variants come back in insert order.
    final byId = {for (final p in await productsRepo.products()) p.id!: p};
    final products = [for (final id in productIds) byId[id]!];
    onProgress?.call(0.15);

    final sessionIds = <int>[];
    for (final s in (data['sessions'] as List).cast<Map<String, dynamic>>()) {
      sessionIds.add(await sessionsRepo.add(CalendarSession(
        googleId: s['google_id'] as String?,
        title: s['title'] as String,
        start: fromDb(s['start'] as String),
        end: fromDb(s['end'] as String),
      )));
    }

    // ----------------------------------------------------------- history
    final events = (data['events'] as List).cast<Map<String, dynamic>>();
    var saleCount = 0, refundCount = 0, restockCount = 0;
    await _db.transaction((txn) async {
      final orderIds = <int>[];
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        final at = fromDb(e['at'] as String);
        switch (e['t']) {
          case 'sale':
            final lines = [
              for (final l in (e['lines'] as List).cast<List>())
                CartLine(
                  product: products[l[0] as int],
                  variant: products[l[0] as int].variants[l[1] as int],
                  quantity: l[2] as int,
                ),
            ];
            final orderId = await SqliteSalesRepository.recordSale(
              txn,
              lines: lines,
              paymentMethod: e['pay'] as String,
              discount: e['discount'] == null ? null : discounts[e['discount']],
              at: at,
            );
            orderIds.add(orderId);
            if (e['manual_session'] != null) {
              await SqliteSalesRepository.setSessionWith(txn, orderId, sessionIds[e['manual_session'] as int]);
            }
            saleCount++;
          case 'refund':
            final orderId = orderIds[e['sale'] as int];
            final itemIds = (await txn.query('order_items',
                    columns: ['id'], where: 'order_id = ?', whereArgs: [orderId], orderBy: 'id'))
                .map((r) => r['id'] as int)
                .toList();
            await SqliteSalesRepository.recordRefund(
              txn,
              orderId,
              {for (final l in (e['lines'] as List).cast<List>()) itemIds[l[0] as int]: l[1] as int},
              at: at,
            );
            refundCount++;
          case 'restock':
            final Product p = products[e['p'] as int];
            await SqliteProductRepository.restockWith(txn, p.variants[e['v'] as int].id!, e['q'] as int, at);
            restockCount++;
        }
        if (onProgress != null && i % 100 == 0) onProgress(0.15 + 0.85 * i / events.length);
      }
    });
    onProgress?.call(1);

    return DemoLoadResult(
      artists: artistIds.length,
      products: products.length,
      variants: products.fold(0, (s, p) => s + p.variants.length),
      sales: saleCount,
      refunds: refundCount,
      restocks: restockCount,
      sessions: sessionIds.length,
    );
  }
}
