import 'package:flutter/material.dart';

/// Shows messages from places without a BuildContext (e.g. after a file
/// download finishes). Attached to MaterialApp in app.dart.
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppMessage(String message, {String? actionLabel, VoidCallback? onAction, bool error = false}) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  final context = appMessengerKey.currentContext;
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error && context != null ? Theme.of(context).colorScheme.error : null,
    duration: Duration(seconds: actionLabel == null ? 4 : 8),
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}
