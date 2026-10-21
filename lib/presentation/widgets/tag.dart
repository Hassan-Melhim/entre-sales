import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Small pill used for stock warnings, statuses and custom rates.
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Tag(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconTag, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: style)),
        ],
      ),
    );
  }
}
