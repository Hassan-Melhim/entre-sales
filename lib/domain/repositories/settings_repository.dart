/// Simple key/value settings.
abstract interface class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String? value);
}

/// Keys used with [SettingsRepository].
class SettingKeys {
  SettingKeys._();
  static const calendarId = 'calendar_id';
  static const calendarAccount = 'calendar_account';
  static const calendarLastSync = 'calendar_last_sync';
  static const storeName = 'store_name';
  static const storeAddress = 'store_address';
  static const storeTaxId = 'store_tax_id';

  /// 'system', 'light' or 'dark'.
  static const themeMode = 'theme_mode';
}
