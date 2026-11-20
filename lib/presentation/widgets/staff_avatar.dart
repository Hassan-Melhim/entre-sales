import 'package:flutter/material.dart';

import '../staff_accounts.dart';
import '../theme/app_tokens.dart';

/// A round avatar with the person's icon.
class StaffAvatar extends StatelessWidget {
  final StaffAccount? staff;
  final int colorIndex;
  final double size;
  const StaffAvatar(this.staff, {super.key, this.colorIndex = 0, this.size = AppSizes.avatarLarge});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = switch (colorIndex % 3) {
      0 => (c.primaryContainer, c.onPrimaryContainer),
      1 => (c.secondaryContainer, c.onSecondaryContainer),
      _ => (c.tertiaryContainer, c.onTertiaryContainer),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(staff?.icon ?? Icons.person_outline, color: fg, size: size * 0.5),
    );
  }
}
