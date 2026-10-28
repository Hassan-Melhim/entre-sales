import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/app_shell.dart';
import 'screens/login/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_messenger.dart';
import 'widgets/idle_sign_out.dart';

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
    // After every sign-in, reload all data.
    ref.listen(currentUserProvider, (previous, next) {
      if (previous?.valueOrNull?.id != next.valueOrNull?.id) {
        ref.read(dataRevisionProvider.notifier).state++;
      }
    });

    final user = ref.watch(currentUserProvider);
    return user.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const LoginScreen(),
      data: (u) => u == null ? const LoginScreen() : const IdleSignOut(child: AppShell()),
    );
  }
}
