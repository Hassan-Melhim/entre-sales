import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_config.dart';
import '../../../core/money.dart';
import '../../../domain/business_rules.dart';
import '../../../domain/models/category_attribute.dart';
import '../../../domain/models/product_category.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/info_row.dart';
import 'import_screen.dart';
import 'photo_import_screen.dart';
import 'settings_section.dart';

/// Settings used rarely or only when setting things up.
class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced settings')),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.s, bottom: AppSpacing.xxl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.contentMax),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CategoriesSection(),
                  _ImportSection(),
                  _PhotosSection(),
                  _LogosSection(),
                  _RulesSection(),
                  _AboutSection(),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return SettingsSection(
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

// ------------------------------------------------------------------ Import

class _ImportSection extends StatelessWidget {
  const _ImportSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Import data',
      subtitle: 'Bring in artists, products with stock, and past sales from the old system, '
          'using the import template saved as CSV files. Everything is checked before anything is added.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Import data'),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Photos

class _PhotosSection extends StatelessWidget {
  const _PhotosSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Product photos',
      subtitle: 'Give many products their photo at once from a folder laid out like the Google Drive '
          '(category → "Product name - Artist name" → images). Best done on a Mac. '
          'Single photos can be added in each product\'s form.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoImportScreen())),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Import photos'),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- Logos

class _LogosSection extends StatelessWidget {
  const _LogosSection();

  @override
  Widget build(BuildContext context) => const SettingsSection(
        title: 'Logos for PDFs',
        subtitle: 'Read from Supabase Storage, bucket "${LogoFiles.bucket}": '
            '${LogoFiles.corner} (corner), ${LogoFiles.footer} (footer), ${LogoFiles.kisses} (kisses)',
        children: [_LogoStatus()],
      );
}

/// Whether the PDF logos could be read from Supabase Storage, and why not.
class _LogoStatus extends ConsumerWidget {
  const _LogoStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logos = ref.watch(storeLogosProvider);
    final theme = Theme.of(context);
    final reload = TextButton.icon(
      onPressed: () => ref.invalidate(storeLogosProvider),
      icon: const Icon(Icons.refresh),
      label: const Text('Reload logos'),
    );
    return logos.when(
      loading: () => const Row(children: [
        SizedBox.square(dimension: AppSizes.iconSmall, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: AppSpacing.s),
        Text('Loading the logos…'),
      ]),
      error: (e, _) => Row(children: [Expanded(child: Text('Logos: $e')), reload]),
      data: (l) {
        if (l.problems.isEmpty) {
          return Row(children: [
            Icon(Icons.check_circle, color: context.appColors.success, size: AppSizes.iconSmall),
            const SizedBox(width: AppSpacing.s),
            const Expanded(child: Text('Logos for PDFs: all 3 found.')),
            reload,
          ]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logos for PDFs: ${3 - l.problems.length} of 3 found.',
                style: TextStyle(color: theme.colorScheme.error)),
            for (final p in l.problems) SelectableText('• $p', style: theme.textTheme.bodySmall),
            reload,
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------- Business rules

class _RulesSection extends StatelessWidget {
  const _RulesSection();

  @override
  Widget build(BuildContext context) {
    return const SettingsSection(
      title: 'Store and business rules',
      subtitle: 'Fixed in the code: lib/core/app_config.dart (store) and lib/domain/business_rules.dart '
          '(money rules, with the matching rules in supabase/migrations)',
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
        const InfoRow('Store', StoreDetails.name),
        InfoRow('Address', StoreDetails.address.replaceAll('\n', ' ')),
        const InfoRow('NIF', StoreDetails.taxId),
        const Divider(height: AppSpacing.l),
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

// ------------------------------------------------------------------- About

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(currentUserProvider).valueOrNull?.email ?? '—';
    return SettingsSection(
      title: 'About',
      children: [
        const InfoRow('App version', AppConfig.appVersion),
        InfoRow('Database', Uri.parse(AppConfig.supabaseUrl).host),
        InfoRow('Signed in as', email),
        const InfoRow('Guides', 'README.md and SETUP.md in the code repository'),
      ],
    );
  }
}
