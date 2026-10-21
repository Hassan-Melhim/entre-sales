import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

/// A compact "35%" button showing a commission; highlighted when custom.
class CommissionButton extends StatelessWidget {
  final double percent;
  final bool isCustom;
  final String tooltip;
  final VoidCallback onPressed;

  /// Shown after the rate when it is inherited, e.g. "default" or "artist".
  final String inheritedSuffix;

  const CommissionButton({
    super.key,
    required this.percent,
    required this.isCustom,
    required this.tooltip,
    required this.onPressed,
    this.inheritedSuffix = 'default',
  });

  @override
  Widget build(BuildContext context) {
    // Phones: just the rate, to leave room for the product / artist name.
    final suffix = isCustom || context.isCompact ? '' : ' ($inheritedSuffix)';
    final label = Text('${formatPercent(percent)}$suffix');
    const icon = Icon(Icons.percent, size: AppSizes.iconSmall);
    return Tooltip(
      message: tooltip,
      child: isCustom
          ? FilledButton.tonalIcon(onPressed: onPressed, icon: icon, label: label)
          : OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label),
    );
  }
}
