import 'package:sqflite/sqflite.dart';

/// Simple key/value settings stored in the database.
class SettingsRepository {
  final Database db;
  SettingsRepository(this.db);

  static const calendarId = 'calendar_id';
  static const calendarAccount = 'calendar_account';
  static const calendarLastSync = 'calendar_last_sync';
  static const storeName = 'store_name';
  static const storeAddress = 'store_address';
  static const storeTaxId = 'store_tax_id';

  Future<String?> get(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String? value) =>
      db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
