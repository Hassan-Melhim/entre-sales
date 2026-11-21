import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';

/// A titled card on the Settings and Advanced settings screens. With
/// [collapsible], tapping the title shows or hides the contents (hidden at
/// first unless [initiallyExpanded]).
class SettingsSection extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? action;
  final bool collapsible;
  final bool initiallyExpanded;

  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.action,
    this.collapsible = false,
    this.initiallyExpanded = false,
  });

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  late bool _expanded = !widget.collapsible || widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final theme = Theme.of(context);
    Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: theme.textTheme.titleMedium),
        if (widget.subtitle != null) Text(widget.subtitle!, style: TextStyle(color: theme.colorScheme.outline)),
      ],
    );
    if (widget.collapsible) {
      heading = InkWell(
        borderRadius: BorderRadius.circular(AppRadius.s),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: heading),
            const SizedBox(width: AppSpacing.s),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, semanticLabel: _expanded ? 'Hide' : 'Show'),
            ),
          ],
        ),
      );
    }
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
                children: [heading, if (widget.action != null) widget.action!],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SizedBox(height: AppSpacing.m), ...widget.children],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
