import 'package:flutter/material.dart';

import '../theme/breakpoints.dart';

/// A button that shows its label on wide screens and only its icon (with a
/// tooltip) on phones, to save space in headers.
class AdaptiveButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  const AdaptiveButton({super.key, required this.icon, required this.label, this.onPressed, this.filled = false});

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return filled
          ? IconButton.filled(onPressed: onPressed, icon: Icon(icon), tooltip: label)
          : IconButton.outlined(onPressed: onPressed, icon: Icon(icon), tooltip: label);
    }
    return filled
        ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label))
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
  }
}
