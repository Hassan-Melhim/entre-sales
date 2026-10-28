import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/repositories/backup_repository.dart';
import '../supabase_errors.dart';
import '../supabase_paging.dart';

/// Downloads every table as one JSON file.
class SupabaseBackupRepository implements BackupRepository {
  final SupabaseClient _db;
  SupabaseBackupRepository(this._db);

  /// Tables and the column that gives them a fixed order (for paging).
  static const _tables = {
    'settings': 'key',
    'artists': 'id',
    'categories': 'id',
    'category_attributes': 'id',
    'products': 'id',
    'variants': 'id',
    'discounts': 'id',
    'calendar_events': 'id',
    'orders': 'id',
    'order_items': 'id',
    'refunds': 'id',
    'audit_log': 'id',
  };

  @override
  Future<List<int>> exportBackup() => guard(() async {
        final data = <String, Object?>{
          'app': 'Entre Sales',
          'exported_at': DateTime.now().toUtc().toIso8601String(),
        };
        for (final e in _tables.entries) {
          data[e.key] = await fetchAllPages((from, to) => _db.from(e.key).select().order(e.value).range(from, to));
        }
        return utf8.encode(const JsonEncoder.withIndent(' ').convert(data));
      });
}
