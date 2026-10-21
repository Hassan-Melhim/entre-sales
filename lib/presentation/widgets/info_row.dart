import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

/// Label / value pair laid out side by side on wide screens and stacked on
/// phones (for settings and summaries).
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(vertical: AppSpacing.xs);
    if (context.isCompact) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(label, style: Theme.of(context).textTheme.labelLarge), Text(value)],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: AppSizes.infoLabel), child: Text(label)),
          const SizedBox(width: AppSpacing.m),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
