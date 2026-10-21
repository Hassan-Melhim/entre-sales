import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.emptyStateIcon, color: color),
            const SizedBox(height: AppSpacing.m),
            Text(message, style: TextStyle(color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
