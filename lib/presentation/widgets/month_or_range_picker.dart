import 'package:flutter/material.dart';

import '../../domain/models/report_period.dart';
import '../theme/app_tokens.dart';
import 'date_range_field.dart';

/// "Month" (with previous / next arrows) or "Date range" (From / To dates).
/// Used by Invoices and Sales.
class MonthOrRangePicker extends StatelessWidget {
  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  const MonthOrRangePicker({super.key, required this.period, required this.onChanged});

  bool get _isCustom => period.kind == PeriodKind.custom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.m,
      runSpacing: AppSpacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Month'), icon: Icon(Icons.calendar_month)),
            ButtonSegment(value: true, label: Text('Date range'), icon: Icon(Icons.date_range)),
          ],
          selected: {_isCustom},
          onSelectionChanged: (s) => onChanged(s.first
              ? ReportPeriod.custom(period.range)
              : ReportPeriod.containing(PeriodKind.month, period.range.start)),
        ),
        if (_isCustom)
          DateRangeField(value: period.range, onChanged: (r) => onChanged(ReportPeriod.custom(r)))
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => onChanged(period.previous()),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(period.label, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => onChanged(period.next()),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
