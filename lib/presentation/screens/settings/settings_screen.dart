import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../data/calendar/google_calendar_service.dart';
import '../../../data/export/export_file.dart';
import '../../../domain/business_rules.dart';
import '../../../domain/models/category_attribute.dart';
import '../../../domain/models/discount.dart';
import '../../../domain/models/product_category.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/file_delivery.dart';
import '../../widgets/info_row.dart';
import '../../widgets/page_header.dart';
import '../../widgets/responsive_fields.dart';
import '../pos/cart.dart';

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
                _AppearanceSection(),
                _StoreSection(),
                _CategoriesSection(),
                _DiscountsSection(),
                _CalendarSection(),
                _RulesSection(),
                _BackupSection(),
                _DemoDataSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? action;
  const _Section({required this.title, this.subtitle, required this.children, this.action});

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
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
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Appearance

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return _Section(
      title: 'Appearance',
      subtitle: 'Saved on this device',
      children: [
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
      ],
    );
  }
}

// ------------------------------------------------------------------- Store

class _StoreSection extends ConsumerStatefulWidget {
  const _StoreSection();
  @override
  ConsumerState<_StoreSection> createState() => _StoreSectionState();
}

class _StoreSectionState extends ConsumerState<_StoreSection> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _taxId = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = ref.read(settingsRepositoryProvider);
    _name.text = await s.get(SettingKeys.storeName) ?? 'Entre Salas';
    _address.text = await s.get(SettingKeys.storeAddress) ?? '';
    _taxId.text = await s.get(SettingKeys.storeTaxId) ?? '';
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _taxId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(settingsRepositoryProvider);
    await s.set(SettingKeys.storeName, _name.text.trim());
    await s.set(SettingKeys.storeAddress, _address.text.trim());
    await s.set(SettingKeys.storeTaxId, _taxId.text.trim());
    refreshData(ref);
    if (mounted) showMessage(context, 'Store details saved');
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Store details',
      subtitle: 'Printed at the top of receipts, invoices and reports',
      action: FilledButton(onPressed: _loaded ? _save : null, child: const Text('Save')),
      children: [
        ResponsiveFields(
          flex: const [1, 2, 1],
          minRowWidth: AppLayout.storeFieldsRowMin,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Store name')),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
            TextField(controller: _taxId, decoration: const InputDecoration(labelText: 'NIF / CIF')),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Categories

class _CategoriesSection extends ConsumerWidget {
  const _CategoriesSection();

  String _describe(ProductCategory c) {
    final fields = c.attributes.isEmpty
        ? 'no extra fields'
        : c.attributes
            .map((a) => a.isFreeText ? '${a.name} (free text)' : '${a.name}: ${a.options.join(', ')}')
            .join(' · ');
    return 'Tax ${formatPercent(c.taxPercent)} · $fields';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return _Section(
      title: 'Categories',
      subtitle: 'Tax rate and the extra fields asked when logging a product',
      action: FilledButton.icon(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
      children: [
        AsyncView(
          value: cats,
          builder: (list) => Column(
            children: [
              for (final c in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.name),
                  subtitle: Text(_describe(c)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(context, c),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, ProductCategory? c) =>
      showDialog<void>(context: context, builder: (_) => _CategoryDialog(category: c));
}

class _AttrRow {
  final TextEditingController name;
  final TextEditingController options;
  _AttrRow(String n, String o)
      : name = TextEditingController(text: n),
        options = TextEditingController(text: o);

  void dispose() {
    name.dispose();
    options.dispose();
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  final ProductCategory? category;
  const _CategoryDialog({this.category});
  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.category?.name);
  late final _tax = TextEditingController(text: widget.category?.taxPercent.toString() ?? '21');
  late final List<_AttrRow> _attrs = [
    for (final a in widget.category?.attributes ?? const <CategoryAttribute>[]) _AttrRow(a.name, a.options.join(', ')),
  ];

  @override
  void dispose() {
    _name.dispose();
    _tax.dispose();
    for (final a in _attrs) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final tax = parsePercent(_tax.text);
    if (_name.text.trim().isEmpty || tax == null) {
      showMessage(context, 'Enter a name and a tax rate from 0 to 100', error: true);
      return;
    }
    final attrs = [
      for (final a in _attrs)
        if (a.name.text.trim().isNotEmpty)
          CategoryAttribute(
            name: a.name.text.trim(),
            options: a.options.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
          ),
    ];
    try {
      await ref.read(categoryRepositoryProvider).save(
          ProductCategory(id: widget.category?.id, name: _name.text.trim(), taxPercent: tax, attributes: attrs));
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save (is the name already used?)', error: true);
      return;
    }
    refreshData(ref);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final repo = ref.read(categoryRepositoryProvider);
    if (!await repo.canDelete(widget.category!.id!)) {
      if (mounted) showMessage(context, 'This category has products and cannot be deleted.', error: true);
      return;
    }
    await repo.delete(widget.category!.id!);
    refreshData(ref);
    if (mounted) Navigator.pop(context);
  }

  /// Side by side on wide screens, stacked on phones. (No LayoutBuilder
  /// here: dialog content must report its size up front.)
  Widget _pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => context.isCompact
      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: AppSpacing.s), b])
      : Row(children: [
          Expanded(flex: flexA, child: a),
          const SizedBox(width: AppSpacing.m),
          Expanded(flex: flexB, child: b),
        ]);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: context.dialogWidth(AppSizes.dialogLarge),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pair(
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: _tax,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tax (IVA)', suffixText: '%'),
                ),
                flexA: 2,
              ),
              const SizedBox(height: AppSpacing.l),
              Text('Fields', style: Theme.of(context).textTheme.titleSmall),
              Text('Leave options empty to type values freely, or list fixed options separated by commas.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.s),
              for (var i = 0; i < _attrs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _pair(
                          TextField(
                              controller: _attrs[i].name,
                              decoration: const InputDecoration(labelText: 'Field (e.g. Size)')),
                          TextField(
                            controller: _attrs[i].options,
                            decoration: const InputDecoration(labelText: 'Options (optional)', hintText: 'S, M, L'),
                          ),
                          flexB: 2,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove field',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          final removed = _attrs.removeAt(i);
                          setState(() {});
                          // Dispose once its text fields have left the screen.
                          WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                        },
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _attrs.add(_AttrRow('', ''))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add field'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.category != null)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
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
    return _Section(
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

// ---------------------------------------------------------- Google Calendar

class _CalendarSection extends ConsumerStatefulWidget {
  const _CalendarSection();
  @override
  ConsumerState<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends ConsumerState<_CalendarSection> {
  final _calendarId = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepositoryProvider).get(SettingKeys.calendarId).then((v) {
      if (mounted) _calendarId.text = v ?? '';
    });
  }

  @override
  void dispose() {
    _calendarId.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      refreshData(ref);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const subtitle = 'Events with "${BusinessRules.workshopKeyword}" in the title become workshop sessions. '
        'Sales during a session are tagged automatically.';

    if (!GoogleCalendarService.isSupported) {
      return const _Section(
        title: 'Google Calendar',
        subtitle: subtitle,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('Coming with the shared database'),
            subtitle: Text('Calendar sync will run on the server so every device sees the same sessions. '
                'Until then, add workshop sessions by hand in Invoices → Workshop sessions.'),
          ),
        ],
      );
    }

    final account = ref.watch(settingProvider(SettingKeys.calendarAccount)).valueOrNull;
    final lastSync = ref.watch(settingProvider(SettingKeys.calendarLastSync)).valueOrNull;
    final service = ref.read(calendarServiceProvider);
    return _Section(
      title: 'Google Calendar',
      subtitle: subtitle,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(account ?? 'Not connected'),
          subtitle: Text(lastSync == null ? 'Never synced' : 'Last sync ${formatDateTime(fromDb(lastSync))}'),
        ),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            if (account == null)
              FilledButton(onPressed: _busy ? null : () => _run(() async => service.signIn()), child: const Text('Connect'))
            else ...[
              OutlinedButton(onPressed: _busy ? null : () => _run(service.signOut), child: const Text('Disconnect')),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final n = await service.sync();
                          if (mounted) showMessage(this.context, 'Synced: $n workshop session(s)');
                        }),
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _calendarId,
                decoration: const InputDecoration(
                  labelText: 'Calendar ID',
                  helperText: 'Empty = main calendar of the account',
                  hintText: 'abc123@group.calendar.google.com',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            OutlinedButton(
              onPressed: () async {
                await ref.read(settingsRepositoryProvider).set(SettingKeys.calendarId, _calendarId.text.trim());
                refreshData(ref);
                if (context.mounted) showMessage(context, 'Calendar ID saved');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- Business rules

class _RulesSection extends StatelessWidget {
  const _RulesSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      title: 'Business rules',
      subtitle: 'Changed in the code: lib/domain/business_rules.dart',
      children: [
        _RuleRows(),
      ],
    );
  }
}

class _RuleRows extends StatelessWidget {
  const _RuleRows();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InfoRow('Default store commission', formatPercent(BusinessRules.defaultCommissionPercent)),
        const InfoRow('Commission priority', 'Product → artist → store default'),
        InfoRow(
          'Tax for Spain-resident artists',
          '${formatPercent(BusinessRules.spainResidentArtistTaxPercent)} '
              '${BusinessRules.residentTaxAddedOnTop ? 'added on top of' : 'withheld from'} payout',
        ),
        const InfoRow('Discounts',
            BusinessRules.discountReducesArtistPayout ? 'Reduce the artist payout' : 'Absorbed by the store'),
        InfoRow(
          'Store profit',
          'Customer paid (incl. VAT) − artist payout'
              '${BusinessRules.profitSubtractsArtistResidentTax && BusinessRules.residentTaxAddedOnTop ? ' − resident tax added' : ''}',
        ),
        const InfoRow('Payout periods', 'Calendar month, or any date range'),
      ],
    );
  }
}

// ------------------------------------------------------------------ Backup

class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      return const _Section(
        title: 'Backup',
        subtitle: 'In the browser, data is kept by the browser on this device only. '
            'Automatic backups will come with the shared database.',
        children: [],
      );
    }
    return _Section(
      title: 'Backup',
      subtitle: 'All data lives only on this device. Save a copy of the database regularly.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final bytes = await ref.read(dataAdminRepositoryProvider).exportBackup();
              if (bytes == null) return;
              await deliverExport(
                ExportFile('entre_sales_backup_${fileStamp(DateTime.now())}.db', Uint8List.fromList(bytes), ExportFile.sqlite),
                shareText: 'Entre Sales database backup ${formatDate(DateTime.now())}',
              );
            },
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Save database backup'),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Demo data

/// Replaces all data with the demo data built from the September 2026
/// inventory. Shown on the website (it only holds test data until the shared
/// database exists), on computers and in debug builds; hidden in a release
/// app on a phone or tablet so real data can't be wiped by accident.
class _DemoDataSection extends ConsumerStatefulWidget {
  const _DemoDataSection();

  static bool get _visible =>
      kIsWeb ||
      !kReleaseMode ||
      const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);

  @override
  ConsumerState<_DemoDataSection> createState() => _DemoDataSectionState();
}

class _DemoDataSectionState extends ConsumerState<_DemoDataSection> {
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ok = await confirm(
      context,
      'Load demo data?',
      'This DELETES all artists, products, sales and workshop sessions on this device and replaces them '
          'with demo data (the September 2026 inventory and a mock sales history from June to October).',
      action: 'Delete and load',
    );
    if (!ok || !mounted) return;

    _progress.value = 0;
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Loading demo data…'),
          content: SizedBox(
            width: ctx.dialogWidth(AppSizes.dialogSmall),
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (_, v, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: v),
                  const SizedBox(height: AppSpacing.s),
                  Text('${(v * 100).round()}%'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final json = await rootBundle.loadString(AppAssets.demoData);
      final result =
          await ref.read(dataAdminRepositoryProvider).loadDemoData(json, onProgress: (p) => _progress.value = p);
      ref.read(cartProvider.notifier).clear();
      refreshData(ref);
      navigator.pop();
      if (mounted) showMessage(context, 'Demo data loaded: ${result.summary}');
    } catch (e) {
      navigator.pop();
      refreshData(ref);
      if (mounted) showMessage(context, 'Could not load demo data: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_DemoDataSection._visible) return const SizedBox.shrink();
    return _Section(
      title: 'Demo data',
      subtitle: 'Fill the app with the September 2026 inventory and a mock sales history (June–October 2026) '
          'to try every feature. Replaces all current data.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: _load,
            icon: const Icon(Icons.dataset_outlined),
            label: const Text('Load demo data'),
          ),
        ),
      ],
    );
  }
}
