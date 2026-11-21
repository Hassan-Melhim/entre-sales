import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../domain/business_rules.dart';
import '../../../domain/models/backup_status.dart';
import '../../../domain/models/discount.dart';
import '../../backup_actions.dart';
import '../../providers.dart';
import '../../staff_accounts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_header.dart';
import '../../widgets/staff_avatar.dart';
import 'advanced_settings_screen.dart';
import 'settings_section.dart';

/// Everyday settings. Rarely used ones are under [AdvancedSettingsScreen].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        const PageHeader(title: 'Settings'),
        // Sections keep a readable width on very wide screens.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.contentMax),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _YouSection(),
                _AppearanceSection(),
                _DiscountsSection(),
                _BackupSection(),
                _AdvancedLink(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- You

class _YouSection extends ConsumerWidget {
  const _YouSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(currentUserProvider).valueOrNull?.email ?? '';
    final staff = staffFor(email);
    return SettingsSection(
      title: 'You',
      children: [
        Row(
          children: [
            StaffAvatar(staff,
                colorIndex: staff == null ? 0 : staffAccounts.indexOf(staff), size: AppSizes.avatarMedium),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff?.name ?? email, style: Theme.of(context).textTheme.titleMedium),
                  if (staff != null)
                    Text(email, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => signOutThisDevice(ref),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- This device

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  static String _shiftLabel(int hours) => hours == 0 ? 'No limit' : '$hours hours';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final shift = ref.watch(shiftHoursProvider);
    return SettingsSection(
      title: 'This device',
      subtitle: 'Saved in this browser only, so the iPad and each laptop can differ',
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Text('Stay signed in for', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final h in {...ShiftHoursController.choices, shift})
              ChoiceChip(
                label: Text(_shiftLabel(h)),
                selected: h == shift,
                onSelected: (_) => ref.read(shiftHoursProvider.notifier).set(h),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Counted from signing in on this device (one shift). If it is being used when the time is up, '
            'it waits until it has been left alone for 5 minutes.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// --------------------------------------------------------------- Discounts

class _DiscountsSection extends ConsumerWidget {
  const _DiscountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discounts = ref.watch(discountsProvider);
    return SettingsSection(
      title: 'Discounts',
      subtitle: 'Shown as checkboxes before completing a sale. '
          '${BusinessRules.discountReducesArtistPayout ? 'Discounts reduce the artist payout.' : 'The store absorbs discounts.'}',
      action: FilledButton.icon(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('New discount'),
      ),
      children: [
        AsyncView(
          value: discounts,
          builder: (list) => Column(
            children: [
              for (final d in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${d.name} · ${formatPercent(d.percent)}'),
                  subtitle: Text(d.active ? 'Shown at checkout' : 'Hidden'),
                  onTap: () => _edit(context, ref, d),
                  trailing: Switch(
                    value: d.active,
                    onChanged: (on) async {
                      await ref.read(discountRepositoryProvider).save(d.copyWith(active: on));
                      refreshData(ref);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Discount? d) async {
    final name = TextEditingController(text: d?.name);
    final pct = TextEditingController(text: d?.percent.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d == null ? 'New discount' : 'Edit discount'),
        content: SizedBox(
          width: ctx.dialogWidth(AppSizes.dialogSmall),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: pct,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Percent off', suffixText: '%'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final n = name.text.trim();
    final p = parsePercent(pct.text);
    name.dispose();
    pct.dispose();
    if (ok != true) return;
    if (n.isEmpty || p == null) {
      if (context.mounted) showMessage(context, 'Enter a name and a percent from 0 to 100', error: true);
      return;
    }
    await ref.read(discountRepositoryProvider).save(Discount(id: d?.id, name: n, percent: p, active: d?.active ?? true));
    refreshData(ref);
  }
}

// ------------------------------------------------------------------ Backup

/// Supabase keeps the data; this is an extra copy the owners control
/// (the free Supabase plan makes no automatic backups). The date of the last
/// backup is shared by every device.
class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();
  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _busy = false;

  Future<void> _download() async {
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
    final status = ref.watch(backupStatusProvider);
    final theme = Theme.of(context);
    return SettingsSection(
      title: 'Backup',
      subtitle: 'Downloads all the store\'s data (artists, products, sales, refunds, history of changes) '
          'as one file. Keep the copies somewhere safe (e.g. a "Backups" folder in Google Drive).',
      children: [
        AsyncView(value: status, builder: (s) => _counter(context, s)),
        const SizedBox(height: AppSpacing.m),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _download,
            icon: _busy
                ? const SizedBox.square(dimension: AppSizes.iconSmall, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label: const Text('Download backup'),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          'Suggested: once a week (the app reminds you after ${BackupStatus.dueAfterDays} days), and always '
          'before clearing or importing data. Keep at least the last 4 weekly files.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _counter(BuildContext context, BackupStatus s) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final days = s.daysSince(now);
    final color = switch (s.urgency(now)) {
      BackupUrgency.ok => context.appColors.success,
      BackupUrgency.due => context.appColors.warning,
      BackupUrgency.overdue => theme.colorScheme.error,
    };
    return Row(
      children: [
        Container(
          width: AppSizes.avatarMedium,
          height: AppSizes.avatarMedium,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: days == null
              ? Icon(Icons.priority_high, color: color)
              : Text('$days', style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                days == null
                    ? 'No backup yet'
                    : days == 0
                        ? 'Backed up today'
                        : days == 1
                        ? '1 day since the last backup'
                        : '$days days since the last backup',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
              if (s.at != null)
                Text('${formatDateTime(s.at!)} by ${accountName(s.byEmail)}',
                    style: TextStyle(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Advanced

class _AdvancedLink extends StatelessWidget {
  const _AdvancedLink();

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s, pad, AppSpacing.l),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('Advanced settings'),
          subtitle: const Text('Categories & VAT, import data, logos, store & business rules, about'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen())),
        ),
      ),
    );
  }
}
