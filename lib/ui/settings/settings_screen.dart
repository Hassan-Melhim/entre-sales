import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/business_rules.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/settings_repository.dart';
import '../../models/category_attribute.dart';
import '../../models/discount.dart';
import '../../models/product_category.dart';
import '../../providers.dart';
import '../../services/calendar_service.dart';
import '../../services/file_output_service.dart';
import '../common.dart';
import '../responsive.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const PageHeader(title: 'Settings'),
        // Sections keep a readable width on very wide screens.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StoreSection(),
                _CategoriesSection(),
                _DiscountsSection(),
                _CalendarSection(),
                _RulesSection(),
                _DataSection(),
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
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(context.isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The action button drops under the title when space is short.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        if (subtitle != null)
                          Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
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
    final s = ref.read(settingsRepoProvider);
    _name.text = await s.get(SettingsRepository.storeName) ?? 'Entre';
    _address.text = await s.get(SettingsRepository.storeAddress) ?? '';
    _taxId.text = await s.get(SettingsRepository.storeTaxId) ?? '';
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
    final s = ref.read(settingsRepoProvider);
    await s.set(SettingsRepository.storeName, _name.text.trim());
    await s.set(SettingsRepository.storeAddress, _address.text.trim());
    await s.set(SettingsRepository.storeTaxId, _taxId.text.trim());
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
          minRowWidth: 700,
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
        : c.attributes.map((a) => a.isFreeText ? '${a.name} (free text)' : '${a.name}: ${a.options.join(', ')}').join(' · ');
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
      await ref
          .read(inventoryRepoProvider)
          .saveCategory(ProductCategory(id: widget.category?.id, name: _name.text.trim(), taxPercent: tax, attributes: attrs));
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save (is the name already used?)', error: true);
      return;
    }
    refreshData(ref);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final repo = ref.read(inventoryRepoProvider);
    if (!await repo.canDeleteCategory(widget.category!.id!)) {
      if (mounted) showMessage(context, 'This category has products and cannot be deleted.', error: true);
      return;
    }
    await repo.deleteCategory(widget.category!.id!);
    refreshData(ref);
    if (mounted) Navigator.pop(context);
  }

  /// Side by side on wide screens, stacked on phones. (No LayoutBuilder
  /// here: dialog content must report its size up front.)
  Widget _pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => context.isCompact
      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 8), b])
      : Row(children: [Expanded(flex: flexA, child: a), const SizedBox(width: 12), Expanded(flex: flexB, child: b)]);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: context.dialogWidth(600),
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
                  decoration: const InputDecoration(labelText: 'Tax (IVA) %'),
                ),
                flexA: 2,
              ),
              const SizedBox(height: 16),
              Text('Fields', style: Theme.of(context).textTheme.titleSmall),
              const Text('Leave options empty to type values freely, or list fixed options separated by commas.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              for (var i = 0; i < _attrs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                      await ref
                          .read(discountRepoProvider)
                          .save(Discount(id: d.id, name: d.name, percent: d.percent, active: on));
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
          width: ctx.dialogWidth(400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(
                controller: pct,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Percent off'),
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
    await ref.read(discountRepoProvider).save(Discount(id: d?.id, name: n, percent: p, active: d?.active ?? true));
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
    ref.read(settingsRepoProvider).get(SettingsRepository.calendarId).then((v) {
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

    if (!CalendarService.isSupported) {
      return const _Section(
        title: 'Google Calendar',
        subtitle: subtitle,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('Available on the Android tablet'),
            subtitle: Text('Google sign-in does not work on this computer. '
                'You can still add workshop sessions by hand in Invoices → Workshop sessions.'),
          ),
        ],
      );
    }

    final account = ref.watch(settingProvider(SettingsRepository.calendarAccount)).valueOrNull;
    final lastSync = ref.watch(settingProvider(SettingsRepository.calendarLastSync)).valueOrNull;
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
          spacing: 8,
          runSpacing: 8,
          children: [
            if (account == null)
              FilledButton(
                onPressed: _busy ? null : () => _run(() async => service.signIn()),
                child: const Text('Connect'),
              )
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
        const SizedBox(height: 16),
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
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                await ref.read(settingsRepoProvider).set(SettingsRepository.calendarId, _calendarId.text.trim());
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
    return _Section(
      title: 'Business rules',
      subtitle: 'Changed in the code: lib/config/business_rules.dart',
      children: [
        InfoRow('Default store commission', formatPercent(BusinessRules.defaultCommissionPercent)),
        InfoRow(
          'Tax for Spain-resident artists',
          '${formatPercent(BusinessRules.spainResidentArtistTaxPercent)} '
              '${BusinessRules.residentTaxAddedOnTop ? 'added on top of' : 'withheld from'} payout',
        ),
        InfoRow('Discounts',
            BusinessRules.discountReducesArtistPayout ? 'Reduce the artist payout' : 'Absorbed by the store'),
        InfoRow(
          'Store profit',
          'Customer paid (incl. VAT) − artist payout'
              '${BusinessRules.profitSubtractsArtistResidentTax && BusinessRules.residentTaxAddedOnTop ? ' − resident tax added' : ''}',
        ),
        InfoRow('Payout periods', '1st–15th and 16th–end, or ${BusinessRules.customPeriodDays} days up to a chosen date'),
      ],
    );
  }
}

// -------------------------------------------------------------------- Data

class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Backup',
      subtitle: FileOutputService.isDesktop
          ? 'Test data on this computer is kept separately from the tablet.'
          : 'All data lives only on this tablet. Save a copy of the database regularly.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final file = File(await AppDatabase.databaseFilePath());
              if (!await file.exists()) return;
              await FileOutputService.deliverFile(
                file,
                'entre_sales_backup_${fileStamp(DateTime.now())}.db',
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
