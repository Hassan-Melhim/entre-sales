import 'package:sqflite/sqflite.dart';

import '../../core/dates.dart';
import '../models.dart';

/// Locally cached workshop sessions (from Google Calendar or added by hand).
class CalendarRepository {
  final Database db;
  CalendarRepository(this.db);

  Future<List<CalendarSession>> sessions({DateRange? range}) async {
    final rows = range == null
        ? await db.query('calendar_events', orderBy: 'start_at DESC')
        : await db.query('calendar_events',
            where: 'start_at < ? AND end_at > ?',
            whereArgs: [toDb(range.end), toDb(range.start)],
            orderBy: 'start_at DESC');
    return rows.map(CalendarSession.fromMap).toList();
  }

  Future<CalendarSession?> session(int id) async {
    final rows = await db.query('calendar_events', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CalendarSession.fromMap(rows.first);
  }

  /// The session running at [t], if any.
  Future<CalendarSession?> sessionAt(DateTime t) async {
    final s = toDb(t);
    final rows = await db.query('calendar_events',
        where: 'start_at <= ? AND end_at > ?', whereArgs: [s, s], orderBy: 'start_at DESC', limit: 1);
    return rows.isEmpty ? null : CalendarSession.fromMap(rows.first);
  }

  /// A session added by hand (for a workshop that was not on the calendar).
  Future<int> addManualSession(String title, DateTime start, DateTime end) =>
      db.insert('calendar_events', {'title': title, 'start_at': toDb(start), 'end_at': toDb(end)});

  Future<void> deleteSession(int id) => db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);

  /// Stores the workshop events fetched from Google for [window].
  /// Google events in the window that no longer exist are removed, unless
  /// a sale is tagged with them.
  Future<void> replaceGoogleSessions(DateRange window, List<CalendarSession> fetched) async {
    await db.transaction((txn) async {
      final now = toDb(DateTime.now());
      final seen = <String>{};
      for (final s in fetched) {
        seen.add(s.googleId!);
        final data = {
          'google_id': s.googleId,
          'title': s.title,
          'start_at': toDb(s.start),
          'end_at': toDb(s.end),
          'synced_at': now,
        };
        final updated = await txn.update('calendar_events', data, where: 'google_id = ?', whereArgs: [s.googleId]);
        if (updated == 0) await txn.insert('calendar_events', data);
      }
      final inWindow = await txn.query('calendar_events',
          columns: ['id', 'google_id'],
          where: 'google_id IS NOT NULL AND start_at >= ? AND start_at < ?',
          whereArgs: [toDb(window.start), toDb(window.end)]);
      for (final r in inWindow) {
        if (seen.contains(r['google_id'])) continue;
        final used = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM orders WHERE calendar_event_id = ?', [r['id']])) ??
            0;
        if (used == 0) await txn.delete('calendar_events', where: 'id = ?', whereArgs: [r['id']]);
      }
    });
  }

  /// Tags sales that happened during a session but are not tagged yet.
  /// Sales that were tagged or untagged by hand are left alone.
  Future<int> autoTagSales() async {
    return db.rawUpdate('''
      UPDATE orders
      SET calendar_event_id = (
            SELECT e.id FROM calendar_events e
            WHERE e.start_at <= orders.created_at AND e.end_at > orders.created_at
            ORDER BY e.start_at DESC LIMIT 1),
          event_tag_source = 'auto'
      WHERE event_tag_source IS NULL
        AND EXISTS (SELECT 1 FROM calendar_events e
                    WHERE e.start_at <= orders.created_at AND e.end_at > orders.created_at)''');
  }
}

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
