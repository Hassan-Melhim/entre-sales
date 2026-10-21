import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../domain/models/date_range.dart';
import '../theme/app_tokens.dart';
import 'dialogs.dart';

/// "From" and "To" date buttons. Both may be the same day, to look at a
/// single date. Choosing a "From" after "To" (or the reverse) moves the
/// other date along, so the range is always valid.
class DateRangeField extends StatelessWidget {
  final DateRange value;
  final ValueChanged<DateRange> onChanged;

  /// Show "Today" / "This month" shortcuts.
  final bool showShortcuts;

  const DateRangeField({super.key, required this.value, required this.onChanged, this.showShortcuts = true});

  Future<void> _pickFrom(BuildContext context) async {
    final d = await pickDate(context, value.start);
    if (d == null) return;
    final last = value.lastDay.isBefore(d) ? d : value.lastDay;
    onChanged(DateRange.days(d, last));
  }

  Future<void> _pickTo(BuildContext context) async {
    final d = await pickDate(context, value.lastDay);
    if (d == null) return;
    final first = d.isBefore(value.start) ? d : value.start;
    onChanged(DateRange.days(first, d));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickFrom(context),
          icon: const Icon(Icons.event),
          label: Text('From ${formatDate(value.start)}'),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickTo(context),
          icon: const Icon(Icons.event_available),
          label: Text('To ${formatDate(value.lastDay)}'),
        ),
        if (showShortcuts) ...[
          ActionChip(label: const Text('Today'), onPressed: () => onChanged(DateRange.day(now))),
          ActionChip(label: const Text('This month'), onPressed: () => onChanged(DateRange.month(now.year, now.month))),
        ],
      ],
    );
  }
}
