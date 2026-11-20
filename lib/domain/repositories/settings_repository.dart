/// Store-wide key/value settings, shared by every device.
abstract interface class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String? value);
}
