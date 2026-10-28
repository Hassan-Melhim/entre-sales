import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/calendar_session.dart';
import '../../../domain/models/date_range.dart';
import '../../../domain/repositories/session_repository.dart';
import '../supabase_errors.dart';
import '../supabase_mappers.dart';
import '../supabase_values.dart';

class SupabaseSessionRepository implements SessionRepository {
  final SupabaseClient _db;
  SupabaseSessionRepository(this._db);

  @override
  Future<List<CalendarSession>> sessions({DateRange? range}) => guard(() async {
        var query = _db.from('calendar_events').select();
        if (range != null) {
          query = query.lt('start_at', momentToDb(range.end)).gt('end_at', momentToDb(range.start));
        }
        final rows = asRows(await query.order('start_at', ascending: false));
        return rows.map(SupabaseMappers.session).toList();
      });

  @override
  Future<CalendarSession?> session(int id) => guard(() async {
        final row = await _db.from('calendar_events').select().eq('id', id).maybeSingle();
        return row == null ? null : SupabaseMappers.session(row);
      });

  @override
  Future<CalendarSession?> sessionAt(DateTime t) => guard(() async {
        final at = momentToDb(t);
        final row = await _db
            .from('calendar_events')
            .select()
            .lte('start_at', at)
            .gt('end_at', at)
            .order('start_at', ascending: false)
            .limit(1)
            .maybeSingle();
        return row == null ? null : SupabaseMappers.session(row);
      });

  @override
  Future<int> add(CalendarSession s) => guard(() async {
        final row = await _db
            .from('calendar_events')
            .insert({
              'google_id': s.googleId,
              'title': s.title,
              'start_at': momentToDb(s.start),
              'end_at': momentToDb(s.end),
            })
            .select('id')
            .single();
        return asInt(row['id']);
      });

  @override
  Future<void> delete(int id) => guard(() => _db.from('calendar_events').delete().eq('id', id));

  /// Sales tagged or untagged by hand are left alone.
  @override
  Future<int> autoTagSales() => guard(() async => asInt(await _db.rpc('auto_tag_sales')));
}
