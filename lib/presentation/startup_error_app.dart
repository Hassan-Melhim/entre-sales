import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

/// Shown instead of a blank screen when the app cannot start
/// (usually: the database could not be opened).
class StartupErrorApp extends StatelessWidget {
  final Object error;
  const StartupErrorApp(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    final hint = kIsWeb && '$error'.contains('SqfliteFfiWeb')
        ? 'The browser database files are missing. In the project folder run:\n\n'
            'dart run sqflite_common_ffi_web:setup\n\n'
            'then start the app again.'
        : 'Restart the app. If it keeps happening, send this message to whoever maintains the app.';
    return MaterialApp(
      title: 'Entre Sales',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.dialogLarge),
              child: Builder(
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: AppSizes.iconLarge, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: AppSpacing.m),
                    Text('Entre Sales could not start', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.m),
                    SelectableText(hint),
                    const SizedBox(height: AppSpacing.l),
                    SelectableText('$error', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
