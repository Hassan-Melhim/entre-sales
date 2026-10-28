/// Preferences that belong to one device (and browser) only, such as light
/// or dark mode. Read synchronously, so they can be used while the app
/// starts.
abstract interface class DeviceSettingsRepository {
  String? get(String key);
  Future<void> set(String key, String? value);
}

/// Keys used with [DeviceSettingsRepository].
class DeviceSettingKeys {
  DeviceSettingKeys._();

  /// 'system', 'light' or 'dark'.
  static const themeMode = 'theme_mode';

  /// Minutes without use before signing out; '0' = never.
  static const idleSignOutMinutes = 'idle_sign_out_minutes';
}
