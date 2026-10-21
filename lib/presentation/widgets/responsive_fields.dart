import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Puts [children] side by side when the available width is at least
/// [minRowWidth], and stacks them otherwise.
///
/// [flex] (optional) sets each child's share of the row.
/// Not for use directly inside AlertDialog content (it uses LayoutBuilder);
/// in dialogs choose with `context.isCompact` instead.
class ResponsiveFields extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double minRowWidth;
  final double spacing;
  final CrossAxisAlignment rowAlignment;

  const ResponsiveFields({
    super.key,
    required this.children,
    required this.minRowWidth,
    this.flex,
    this.spacing = AppSpacing.m,
    this.rowAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= minRowWidth) {
        return Row(
          crossAxisAlignment: rowAlignment,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(flex: flex == null ? 1 : flex![i], child: children[i]),
            ],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    });
  }
}
