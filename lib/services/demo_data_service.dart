import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../data/repositories/calendar_repository.dart';
import '../data/repositories/discount_repository.dart';
import '../data/repositories/inventory_repository.dart';
import '../data/repositories/sales_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../models/artist.dart';
import '../models/calendar_session.dart';
import '../models/cart_line.dart';
import '../models/category_attribute.dart';
import '../models/demo_load_result.dart';
import '../models/discount.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/variant.dart';

/// Replaces everything in the database with the demo data in
/// assets/demo/demo_data.json (built by tool/demo_data/generate_demo_data.py
/// from the September 2026 inventory export).
///
/// The sales history is replayed through the same code the shop uses
/// ([SalesRepository.recordSale] / [SalesRepository.recordRefund]), so every
/// amount, payout and stock level is calculated exactly as for real sales.
class DemoDataService {
  DemoDataService._();

  static const String assetPath = 'assets/demo/demo_data.json';

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

  /// Deletes all shop data (settings such as the Google account are kept).
  static Future<void> wipe(Database db) async {
    await db.transaction((txn) async {
      for (final t in _tables) {
        await txn.delete(t);
      }
      // Start ids from 1 again so order numbers look natural.
      await txn.execute('DELETE FROM sqlite_sequence');
    });
  }

  /// Loads [json] (the contents of [assetPath]) into [db].
  /// [onProgress] receives values from 0 to 1.
  static Future<DemoLoadResult> load(Database db, String json, {void Function(double progress)? onProgress}) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final inventory = InventoryRepository(db);
    final sales = SalesRepository(db);
    final calendar = CalendarRepository(db);
    final discountsRepo = DiscountRepository(db);
    final settings = SettingsRepository(db);

    onProgress?.call(0);
    await wipe(db);
    await settings.set(SettingsRepository.storeName, (data['store'] as Map)['name'] as String);

    // ----------------------------------------------------------- catalog
    final categoryIds = <String, int>{};
    for (final c in (data['categories'] as List).cast<Map<String, dynamic>>()) {
      final attrs = (c['attributes'] as List)
          .cast<Map<String, dynamic>>()
          .map((a) => CategoryAttribute(name: a['name'] as String, options: (a['options'] as List).cast<String>()))
          .toList();
      final name = c['name'] as String;
      categoryIds[name] = await inventory
          .saveCategory(ProductCategory(name: name, taxPercent: (c['tax'] as num).toDouble(), attributes: attrs));
    }

    for (final d in (data['discounts'] as List).cast<Map<String, dynamic>>()) {
      await discountsRepo.save(Discount(name: d['name'] as String, percent: (d['percent'] as num).toDouble()));
    }
    final discounts = {for (final d in await discountsRepo.discounts()) d.name: d};

    final artistIds = <String, int>{};
    for (final a in (data['artists'] as List).cast<Map<String, dynamic>>()) {
      final name = a['name'] as String;
      artistIds[name] = await inventory.saveArtist(Artist(
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

    final productJson = (data['products'] as List).cast<Map<String, dynamic>>();
    final productIds = <int>[];
    for (final p in productJson) {
      final variants = (p['variants'] as List).cast<Map<String, dynamic>>().map((v) => Variant(
            attributes: (v['attrs'] as Map).map((k, val) => MapEntry('$k', '$val')),
            quantity: v['qty'] as int,
            priceOverrideCents: v['price'] as int?,
            dateOfArrival: fromDb(v['arrival'] as String),
          ));
      productIds.add(await inventory.saveProduct(
        name: p['name'] as String,
        artistId: artistIds[p['artist']]!,
        categoryId: categoryIds[p['category']]!,
        basePriceCents: p['base'] as int,
        perVariantPricing: p['per_variant'] as bool,
        taxPercentOverride: (p['tax_override'] as num?)?.toDouble(),
        variants: variants.toList(),
      ));
    }
    // Reload with artist / category details; variants come back in insert order.
    final byId = {for (final p in await inventory.products()) p.id!: p};
    final products = [for (final id in productIds) byId[id]!];
    onProgress?.call(0.15);

    final sessionIds = <int>[];
    for (final s in (data['sessions'] as List).cast<Map<String, dynamic>>()) {
      sessionIds.add(await calendar.addSession(CalendarSession(
        googleId: s['google_id'] as String?,
        title: s['title'] as String,
        start: fromDb(s['start'] as String),
        end: fromDb(s['end'] as String),
      )));
    }

    // ----------------------------------------------------------- history
    final events = (data['events'] as List).cast<Map<String, dynamic>>();
    var saleCount = 0, refundCount = 0, restockCount = 0;
    await db.transaction((txn) async {
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
            final orderId = await sales.recordSale(
              txn,
              lines: lines,
              paymentMethod: e['pay'] as String,
              discount: e['discount'] == null ? null : discounts[e['discount']],
              at: at,
            );
            orderIds.add(orderId);
            if (e['manual_session'] != null) {
              await sales.setSession(orderId, sessionIds[e['manual_session'] as int], using: txn);
            }
            saleCount++;
          case 'refund':
            final orderId = orderIds[e['sale'] as int];
            final itemIds = (await txn.query('order_items',
                    columns: ['id'], where: 'order_id = ?', whereArgs: [orderId], orderBy: 'id'))
                .map((r) => r['id'] as int)
                .toList();
            await sales.recordRefund(
              txn,
              orderId,
              {for (final l in (e['lines'] as List).cast<List>()) itemIds[l[0] as int]: l[1] as int},
              at: at,
            );
            refundCount++;
          case 'restock':
            final Product p = products[e['p'] as int];
            await inventory.restock(p.variants[e['v'] as int].id!, e['q'] as int, at, using: txn);
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
