import 'package:sqflite_common/sqlite_api.dart';

import '../../../domain/repositories/settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  final Database _db;
  SqliteSettingsRepository(this._db);

  @override
  Future<String?> get(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> set(String key, String? value) =>
      _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
