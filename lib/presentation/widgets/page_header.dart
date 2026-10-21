import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

/// Page title with action buttons. The actions move under the title when
/// there is not enough room beside it.
class PageHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget? bottom;
  const PageHeader({super.key, required this.title, this.actions = const [], this.bottom});

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, context.isCompact ? AppSpacing.m : AppSpacing.l + AppSpacing.xs, pad, AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.l,
            runSpacing: AppSpacing.s,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (actions.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: AppSpacing.m), bottom!],
        ],
      ),
    );
  }
}
