import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/device_settings_repository.dart';
import '../providers.dart';
import 'app_messenger.dart';

/// Signs this device out when its shift is over: [ShiftHoursController]
/// hours after signing in (5 by default). It never signs out in the middle
/// of use: once the time is up, it waits until nobody has tapped, clicked,
/// scrolled or typed for [_quietPeriod].
///
/// Checked against the clock, so a device that was asleep or had the page
/// in the background past the end of the shift signs out when it wakes.
class ShiftSignOut extends ConsumerStatefulWidget {
  final Widget child;
  const ShiftSignOut({super.key, required this.child});

  @override
  ConsumerState<ShiftSignOut> createState() => _ShiftSignOutState();
}

class _ShiftSignOutState extends ConsumerState<ShiftSignOut> with WidgetsBindingObserver {
  static const _quietPeriod = Duration(minutes: 5);
  static const _checkEvery = Duration(seconds: 30);

  late DateTime _signedInAt;
  DateTime _lastActivity = DateTime.now();
  Timer? _timer;
  bool _signingOut = false;

  DeviceSettingsRepository get _device => ref.read(deviceSettingsProvider);

  @override
  void initState() {
    super.initState();
    // Remembered across page reloads; a new sign-in starts a new shift.
    final saved = DateTime.tryParse(_device.get(DeviceSettingKeys.signedInAt) ?? '');
    if (saved == null) {
      _signedInAt = DateTime.now();
      _device.set(DeviceSettingKeys.signedInAt, _signedInAt.toIso8601String());
    } else {
      _signedInAt = saved;
    }
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(_checkEvery, (_) => _check());
    // Page opened again after the shift ended (e.g. the next morning).
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(justOpened: true));
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

  /// Back to the tab or waking the device: the time away counts as unused.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool justOpened = false}) async {
    final hours = ref.read(shiftHoursProvider);
    if (hours <= 0 || _signingOut) return;
    final now = DateTime.now();
    if (now.difference(_signedInAt) < Duration(hours: hours)) return;
    if (!justOpened && now.difference(_lastActivity) < _quietPeriod) return;

    _signingOut = true;
    await _device.set(DeviceSettingKeys.signedInAt, null);
    await ref.read(authRepositoryProvider).signOut();
    showAppMessage('Signed out: the $hours-hour shift on this device has ended. Sign in again to continue.');
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
