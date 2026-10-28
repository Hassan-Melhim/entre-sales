/// Store-wide key/value settings, shared by every device.
abstract interface class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String? value);
}

/// Keys used with [SettingsRepository].
class SettingKeys {
  SettingKeys._();
  static const storeName = 'store_name';
  static const storeAddress = 'store_address';
  static const storeTaxId = 'store_tax_id';
}
