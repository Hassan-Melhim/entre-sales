import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_user.dart';
import '../domain/repositories/device_settings_repository.dart';
import 'providers.dart';
import 'screens/app_shell.dart';
import 'screens/login/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_messenger.dart';
import 'widgets/shift_sign_out.dart';

class EntreApp extends ConsumerWidget {
  const EntreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Entre Sales',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const AuthGate(),
    );
  }
}

/// Shows the login screen until an owner signs in, then the app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentUserProvider, (previous, next) {
      // A sign-in from the login screen starts a new shift on this device.
      // (A sign-in restored when the page opens keeps its original start.)
      final wasSignedOut = previous is AsyncData<AppUser?> && previous.value == null;
      if (wasSignedOut && next.valueOrNull != null) {
        ref.read(deviceSettingsProvider).set(DeviceSettingKeys.signedInAt, DateTime.now().toIso8601String());
      }
      // After every sign-in or sign-out, reload all data.
      if (previous?.valueOrNull?.id != next.valueOrNull?.id) {
        ref.read(dataRevisionProvider.notifier).state++;
      }
    });

    final user = ref.watch(currentUserProvider);
    return user.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const LoginScreen(),
      data: (u) => u == null ? const LoginScreen() : const ShiftSignOut(child: AppShell()),
    );
  }
}
