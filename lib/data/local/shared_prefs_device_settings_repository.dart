import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/device_settings_repository.dart';

/// Device preferences stored by the browser (local storage).
class SharedPrefsDeviceSettingsRepository implements DeviceSettingsRepository {
  final SharedPreferences _prefs;
  SharedPrefsDeviceSettingsRepository(this._prefs);

  static Future<SharedPrefsDeviceSettingsRepository> open() async =>
      SharedPrefsDeviceSettingsRepository(await SharedPreferences.getInstance());

  @override
  String? get(String key) => _prefs.getString(key);

  @override
  Future<void> set(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }
}
