import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_messenger.dart';

/// Signs out after this device has not been used (no tap, click, scroll or
/// key press) for the minutes chosen in Settings. Checked against the clock,
/// so it also works after the iPad or laptop was asleep.
class IdleSignOut extends ConsumerStatefulWidget {
  final Widget child;
  const IdleSignOut({super.key, required this.child});

  @override
  ConsumerState<IdleSignOut> createState() => _IdleSignOutState();
}

class _IdleSignOutState extends ConsumerState<IdleSignOut> with WidgetsBindingObserver {
  static const _checkEvery = Duration(seconds: 20);

  DateTime _lastActivity = DateTime.now();
  Timer? _timer;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(_checkEvery, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _touch();
    return false; // let the key through
  }

  void _touch() => _lastActivity = DateTime.now();

  /// Coming back to the tab or waking the device: check straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final minutes = ref.read(idleSignOutMinutesProvider);
    if (minutes <= 0 || _signingOut) return;
    if (DateTime.now().difference(_lastActivity) < Duration(minutes: minutes)) return;
    _signingOut = true;
    await ref.read(authRepositoryProvider).signOut();
    showAppMessage('Signed out after $minutes minutes without use');
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      onPointerMove: (_) => _touch(),
      onPointerSignal: (_) => _touch(),
      child: widget.child,
    );
  }
}
