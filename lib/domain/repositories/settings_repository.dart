/// Store-wide key/value settings, shared by every device.
abstract interface class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String? value);
}

/// Keys of the store-wide settings.
abstract final class SharedSettingKeys {
  /// When a backup was last downloaded, from any device (ISO 8601, UTC).
  static const lastBackupAt = 'last_backup_at';

  /// Email of the login that downloaded it.
  static const lastBackupBy = 'last_backup_by';
}
