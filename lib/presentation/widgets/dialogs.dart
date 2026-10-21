import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? Theme.of(context).colorScheme.error : null,
  ));
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Confirm'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: ctx.dialogWidth(AppSizes.dialogSmall), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

/// Pick a single date.
Future<DateTime?> pickDate(BuildContext context, DateTime initial, {DateTime? first, DateTime? last}) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2020),
      lastDate: last ?? DateTime(2100),
    );
