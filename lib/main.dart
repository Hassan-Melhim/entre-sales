import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'data/local/shared_prefs_device_settings_repository.dart';
import 'presentation/app.dart';
import 'presentation/providers.dart';
import 'presentation/startup_error_app.dart';
import 'presentation/widgets/app_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPrefsDeviceSettingsRepository deviceSettings;
  try {
    // Connects to the shared database; a previous sign-in on this browser
    // is restored automatically.
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
    deviceSettings = await SharedPrefsDeviceSettingsRepository.open();
  } catch (e) {
    // A message instead of a blank screen.
    runApp(StartupErrorApp(e));
    return;
  }

  // Anything that fails without its own message (e.g. a save while the
  // internet is down) is shown at the bottom of the screen.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('$error\n$stack');
    showAppMessage('$error', error: true);
    return true;
  };

  runApp(ProviderScope(
    overrides: [deviceSettingsProvider.overrideWithValue(deviceSettings)],
    child: const EntreApp(),
  ));
}
