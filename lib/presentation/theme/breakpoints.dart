import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_tokens.dart';

/// Screen width classes, following Material 3 window size classes.
///
/// - compact:  phones and narrow windows   (< 600 dp)
/// - medium:   iPad portrait, small laptop windows (600–999 dp)
/// - expanded: iPad landscape, laptops     (≥ 1000 dp)
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
  double get pagePadding => isCompact ? AppSpacing.l : AppSpacing.xl;

  /// Width for dialog content: [preferred] when there is room, otherwise
  /// whatever fits inside the dialog on this screen.
  double dialogWidth([double preferred = AppSizes.dialogMedium]) {
    // Dialog inset + content padding on each side.
    final chrome = isCompact ? 2 * (AppSpacing.l + AppSpacing.xl) : 2 * (AppSpacing.xxl + AppSpacing.xxl);
    final available = MediaQuery.sizeOf(this).width - chrome;
    return math.max(AppSizes.dialogMin, math.min(preferred, available));
  }
}
