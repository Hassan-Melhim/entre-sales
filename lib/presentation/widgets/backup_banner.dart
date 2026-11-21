import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../domain/models/backup_status.dart';
import '../../domain/repositories/device_settings_repository.dart';
import '../backup_actions.dart';
import '../providers.dart';
import '../staff_accounts.dart';
import '../theme/app_colors.dart';
import 'dialogs.dart';

/// A reminder across the top of the app when the last backup (from any
/// device) is a week old or more. "Not today" hides it on this device until
/// tomorrow.
class BackupBanner extends ConsumerStatefulWidget {
  const BackupBanner({super.key});

  @override
  ConsumerState<BackupBanner> createState() => _BackupBannerState();
}

class _BackupBannerState extends ConsumerState<BackupBanner> {
  bool _busy = false;

  String get _today => fileStamp(DateTime.now());

  Future<void> _hideToday() async {
    await ref.read(deviceSettingsProvider).set(DeviceSettingKeys.backupBannerHiddenOn, _today);
    if (mounted) setState(() {});
  }

  Future<void> _backUp() async {
    setState(() => _busy = true);
    try {
      await downloadBackup(ref);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not make the backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(backupStatusProvider).valueOrNull;
    final hiddenOn = ref.read(deviceSettingsProvider).get(DeviceSettingKeys.backupBannerHiddenOn);
    final now = DateTime.now();
    if (status == null || hiddenOn == _today) return const SizedBox.shrink();
    final urgency = status.urgency(now);
    if (urgency == BackupUrgency.ok) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final color = urgency == BackupUrgency.overdue ? scheme.error : context.appColors.warning;
    final days = status.daysSince(now);
    final text = days == null
        ? 'No backup of the store\'s data has been downloaded yet.'
        : 'The last backup was $days days ago (by ${accountName(status.byEmail)}). '
            'Download one: it takes a few seconds.';
    return MaterialBanner(
      leading: Icon(Icons.backup_outlined, color: color),
      backgroundColor: color.withValues(alpha: 0.08),
      content: Text(text),
      actions: [
        TextButton(onPressed: _busy ? null : _hideToday, child: const Text('Not today')),
        FilledButton.tonal(
          onPressed: _busy ? null : _backUp,
          child: Text(_busy ? 'Downloading…' : 'Back up now'),
        ),
      ],
    );
  }
}
