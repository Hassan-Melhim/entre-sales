import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/dates.dart';
import '../../../domain/models/calendar_session.dart';
import '../../../domain/models/date_range.dart';
import '../../../domain/repositories/session_repository.dart';
import '../db_values.dart';
import '../sqlite_mappers.dart';

class SqliteSessionRepository implements SessionRepository {
  final Database _db;
  SqliteSessionRepository(this._db);

  @override
  Future<List<CalendarSession>> sessions({DateRange? range}) async {
    final rows = range == null
        ? await _db.query('calendar_events', orderBy: 'start_at DESC')
        : await _db.query('calendar_events',
            where: 'start_at < ? AND end_at > ?', whereArgs: [toDb(range.end), toDb(range.start)], orderBy: 'start_at DESC');
    return rows.map(SqliteMappers.session).toList();
  }

  @override
  Future<CalendarSession?> session(int id) async {
    final rows = await _db.query('calendar_events', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SqliteMappers.session(rows.first);
  }

  @override
  Future<CalendarSession?> sessionAt(DateTime t) async {
    final s = toDb(t);
    final rows = await _db.query('calendar_events',
        where: 'start_at <= ? AND end_at > ?', whereArgs: [s, s], orderBy: 'start_at DESC', limit: 1);
    return rows.isEmpty ? null : SqliteMappers.session(rows.first);
  }

  @override
  Future<int> add(CalendarSession s) => _db.insert('calendar_events', {
        'google_id': s.googleId,
        'title': s.title,
        'start_at': toDb(s.start),
        'end_at': toDb(s.end),
        'synced_at': s.googleId == null ? null : toDb(DateTime.now()),
      });

  @override
  Future<void> delete(int id) => _db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> replaceGoogleSessions(DateRange window, List<CalendarSession> fetched) {
    return _db.transaction((txn) async {
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
        final used = firstInt(await txn.rawQuery('SELECT COUNT(*) FROM orders WHERE calendar_event_id = ?', [r['id']]));
        if (used == 0) await txn.delete('calendar_events', where: 'id = ?', whereArgs: [r['id']]);
      }
    });
  }

  /// Sales tagged or untagged by hand are left alone.
  @override
  Future<int> autoTagSales() => _db.rawUpdate('''
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
