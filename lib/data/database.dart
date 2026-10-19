import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi, sqfliteFfiInit;

import '../config/business_rules.dart';

/// Opens the local SQLite database and creates the schema on first launch.
///
/// Android uses the sqflite plugin. Windows and Linux (for testing on a
/// computer) use sqflite_common_ffi, which talks to SQLite directly.
///
/// Money columns end in `_cents` (integer euro cents).
/// Rate columns end in `_percent` (35.0 = 35%).
/// Date columns hold ISO-8601 local time strings.
class AppDatabase {
  AppDatabase._();

  static const String fileName = 'entre_sales.db';
  static const int schemaVersion = 1;

  /// Windows and Linux need the FFI implementation; everything else uses
  /// the regular sqflite plugin.
  static bool get usesFfi => Platform.isWindows || Platform.isLinux;

  static DatabaseFactory get _platformFactory {
    if (usesFfi) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactorySqflitePlugin;
  }

  /// Opens (and if needed creates) the database.
  ///
  /// [factory] and [path] are only passed by tests (in-memory database).
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? _platformFactory;
    return f.openDatabase(
      path ?? await databaseFilePath(),
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
          await _seed(db);
        },
        // Future schema changes: add `onUpgrade` steps here, one per version.
      ),
    );
  }

  /// Where the database file lives.
  /// - Android: the app's private databases folder.
  /// - Windows: %APPDATA%\com.entre\entre_sales\entre_sales.db
  static Future<String> databaseFilePath() async {
    if (usesFfi) {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      return p.join(dir.path, fileName);
    }
    return p.join(await _platformFactory.getDatabasesPath(), fileName);
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');

    batch.execute('''
      CREATE TABLE artists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gender TEXT,
        address TEXT,
        legal_name TEXT,
        tax_id TEXT,
        iban TEXT,
        bank_name TEXT,
        is_spain_resident INTEGER NOT NULL DEFAULT 1,
        commission_percent REAL,            -- NULL = store default
        created_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        tax_percent REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');

    batch.execute('''
      CREATE TABLE category_attributes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        options TEXT NOT NULL DEFAULT '[]', -- JSON list; empty = free text
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');

    batch.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        artist_id INTEGER NOT NULL REFERENCES artists(id),
        category_id INTEGER NOT NULL REFERENCES categories(id),
        name TEXT NOT NULL,
        base_price_cents INTEGER NOT NULL,  -- before tax
        per_variant_pricing INTEGER NOT NULL DEFAULT 0,
        tax_percent_override REAL,          -- NULL = category rate
        created_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        attributes TEXT NOT NULL DEFAULT '{}', -- JSON map, e.g. {"Size":"M"}
        quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        price_override_cents INTEGER,         -- before tax; used when per_variant_pricing = 1
        date_of_arrival TEXT NOT NULL         -- overwritten on restock
      )''');

    batch.execute('''
      CREATE TABLE discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        percent REAL NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )''');

    batch.execute('''
      CREATE TABLE calendar_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        google_id TEXT UNIQUE,                -- NULL for sessions created by hand
        title TEXT NOT NULL,
        start_at TEXT NOT NULL,
        end_at TEXT NOT NULL,
        synced_at TEXT
      )''');

    batch.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL,                 -- completed | partially_refunded | refunded
        calendar_event_id INTEGER REFERENCES calendar_events(id) ON DELETE SET NULL,
        event_tag_source TEXT,                -- NULL | auto | manual
        discount_id INTEGER REFERENCES discounts(id) ON DELETE SET NULL,
        discount_name TEXT,
        discount_percent REAL NOT NULL DEFAULT 0,
        subtotal_cents INTEGER NOT NULL,      -- after discount, before tax
        discount_cents INTEGER NOT NULL,
        tax_cents INTEGER NOT NULL,
        total_cents INTEGER NOT NULL
      )''');

    // Snapshot columns keep past sales correct even if products, artists
    // or rates are edited later.
    batch.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        variant_id INTEGER REFERENCES variants(id) ON DELETE SET NULL,
        product_id INTEGER,
        artist_id INTEGER NOT NULL REFERENCES artists(id),
        product_name TEXT NOT NULL,
        variant_label TEXT NOT NULL,
        category_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_base_cents INTEGER NOT NULL,
        tax_percent REAL NOT NULL,
        commission_percent REAL NOT NULL,
        discount_percent REAL NOT NULL,
        base_cents INTEGER NOT NULL,          -- after discount, before tax
        discount_cents INTEGER NOT NULL,
        tax_cents INTEGER NOT NULL,
        total_cents INTEGER NOT NULL,
        artist_payout_cents INTEGER NOT NULL, -- before Spain-resident tax
        arrival_date TEXT,                    -- for shelf-life analysis
        refunded_quantity INTEGER NOT NULL DEFAULT 0
      )''');

    batch.execute('''
      CREATE TABLE refunds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_item_id INTEGER NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
        quantity INTEGER NOT NULL,
        base_cents INTEGER NOT NULL,
        tax_cents INTEGER NOT NULL,
        total_cents INTEGER NOT NULL,
        artist_payout_cents INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )''');

    batch.execute('CREATE INDEX idx_products_artist ON products(artist_id)');
    batch.execute('CREATE INDEX idx_variants_product ON variants(product_id)');
    batch.execute('CREATE INDEX idx_orders_created ON orders(created_at)');
    batch.execute('CREATE INDEX idx_items_order ON order_items(order_id)');
    batch.execute('CREATE INDEX idx_items_artist ON order_items(artist_id)');
    batch.execute('CREATE INDEX idx_refunds_created ON refunds(created_at)');

    await batch.commit(noResult: true);
  }

  static Future<void> _seed(Database db) async {
    var order = 0;
    for (final c in seedCategories) {
      final categoryId = await db.insert('categories', {
        'name': c.name,
        'tax_percent': c.taxPercent,
        'sort_order': order++,
      });
      var attrOrder = 0;
      for (final entry in c.attributes.entries) {
        await db.insert('category_attributes', {
          'category_id': categoryId,
          'name': entry.key,
          'options': jsonEncode(entry.value),
          'sort_order': attrOrder++,
        });
      }
    }
    for (final d in seedDiscounts) {
      await db.insert('discounts', {'name': d.name, 'percent': d.percent, 'active': 1});
    }
  }
}
