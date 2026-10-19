import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Screen width classes, following Material 3 window size classes.
///
/// - compact:  phones and narrow windows   (< 600 dp)
/// - medium:   tablets in portrait         (600–999 dp)
/// - expanded: tablets in landscape, PCs   (≥ 1000 dp)
enum ScreenSize { compact, medium, expanded }

class Breakpoints {
  Breakpoints._();
  static const double medium = 600;
  static const double expanded = 1000;

  static ScreenSize of(double width) => width < medium
      ? ScreenSize.compact
      : width < expanded
          ? ScreenSize.medium
          : ScreenSize.expanded;
}

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => Breakpoints.of(MediaQuery.sizeOf(this).width);
  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isExpanded => screenSize == ScreenSize.expanded;

  /// Side padding of pages: tighter on phones.
  double get pagePadding => isCompact ? 16 : 24;

  /// Width for dialog content: [preferred] when there is room, otherwise
  /// whatever fits inside the dialog on this screen.
  double dialogWidth([double preferred = 560]) {
    final available = MediaQuery.sizeOf(this).width - (isCompact ? 80 : 128);
    return math.max(240, math.min(preferred, available));
  }
}

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
    this.flex,
    this.minRowWidth = 640,
    this.spacing = 12,
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
