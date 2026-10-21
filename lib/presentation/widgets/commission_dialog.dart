import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

/// Result of [showCommissionDialog]: the new custom rate, or null to go
/// back to the inherited rate.
class CommissionChoice {
  final double? percent;
  const CommissionChoice(this.percent);
}

/// Quick editor for a commission rate.
///
/// [current] is the custom rate (null if none); [inherited] is what applies
/// without one, described by [inheritedLabel] (e.g. "artist's rate").
/// Returns null when cancelled.
Future<CommissionChoice?> showCommissionDialog(
  BuildContext context, {
  required String title,
  required double? current,
  required double inherited,
  required String inheritedLabel,
}) {
  return showDialog<CommissionChoice>(
    context: context,
    builder: (_) => _CommissionDialog(title: title, current: current, inherited: inherited, inheritedLabel: inheritedLabel),
  );
}

class _CommissionDialog extends StatefulWidget {
  final String title;
  final double? current;
  final double inherited;
  final String inheritedLabel;
  const _CommissionDialog({required this.title, required this.current, required this.inherited, required this.inheritedLabel});

  @override
  State<_CommissionDialog> createState() => _CommissionDialogState();
}

class _CommissionDialogState extends State<_CommissionDialog> {
  late final _controller = TextEditingController(text: widget.current == null ? '' : _plain(widget.current!));
  String? _error;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, const CommissionChoice(null));
      return;
    }
    final v = parsePercent(text);
    if (v == null) {
      setState(() => _error = 'Enter a number from 0 to 100');
      return;
    }
    Navigator.pop(context, CommissionChoice(v));
  }

  @override
  Widget build(BuildContext context) {
    final inherited = '${widget.inheritedLabel}: ${formatPercent(widget.inherited)}';
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: context.dialogWidth(AppSizes.dialogSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Store commission %',
                hintText: 'Empty = $inherited',
                suffixText: '%',
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.s),
            Text('Leave empty to use the $inherited.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const CommissionChoice(null)),
            child: Text('Use ${widget.inheritedLabel}'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
