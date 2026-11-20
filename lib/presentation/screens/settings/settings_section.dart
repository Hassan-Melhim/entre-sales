import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';

/// A titled card on the Settings and Advanced settings screens.
class SettingsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? action;
  const SettingsSection({super.key, required this.title, this.subtitle, required this.children, this.action});

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s, pad, AppSpacing.l),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(context.isCompact ? AppSpacing.m : AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The action button drops under the title when space is short.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.m,
                runSpacing: AppSpacing.s,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
