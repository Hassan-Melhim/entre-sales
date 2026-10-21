import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_tokens.dart';

/// Shows loading / error / data for an AsyncValue.
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  const AsyncView({super.key, required this.value, required this.builder});

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Something went wrong:\n$e', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
