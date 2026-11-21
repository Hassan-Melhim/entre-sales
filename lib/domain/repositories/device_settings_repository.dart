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

  /// How long a sign-in lasts on this device, in hours ('0' = no limit).
  static const shiftHours = 'shift_hours';

  /// When this device signed in (ISO 8601), to know when the shift ends.
  static const signedInAt = 'signed_in_at';

  /// The day (yyyy-mm-dd) the backup reminder banner was hidden on this
  /// device; it comes back the next day.
  static const backupBannerHiddenOn = 'backup_banner_hidden_on';
}
