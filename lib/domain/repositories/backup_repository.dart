/// A copy of all the store's data, for keeping safe outside the database.
abstract interface class BackupRepository {
  /// Every table as JSON (UTF-8 bytes).
  Future<List<int>> exportBackup();
}
