import '../models/demo_load_result.dart';

/// Whole-database operations: demo data and backups.
abstract interface class DataAdminRepository {
  /// Replaces all shop data with the demo data [json].
  Future<DemoLoadResult> loadDemoData(String json, {void Function(double progress)? onProgress});

  /// A copy of the whole database, or null where that is not available
  /// (e.g. in the browser).
  Future<List<int>?> exportBackup();
}
