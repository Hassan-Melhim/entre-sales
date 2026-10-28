import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/repositories/settings_repository.dart';
import '../supabase_errors.dart';

class SupabaseSettingsRepository implements SettingsRepository {
  final SupabaseClient _db;
  SupabaseSettingsRepository(this._db);

  @override
  Future<String?> get(String key) => guard(() async {
        final row = await _db.from('settings').select('value').eq('key', key).maybeSingle();
        return row?['value'] as String?;
      });

  @override
  Future<void> set(String key, String? value) =>
      guard(() => _db.from('settings').upsert({'key': key, 'value': value}));
}
