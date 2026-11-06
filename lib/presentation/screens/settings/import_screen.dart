import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets.dart';
import '../../../core/csv.dart';
import '../../../data/export/export_file.dart';
import '../../../data/files/browser_file_picker.dart';
import '../../../domain/exceptions.dart';
import '../../../domain/import/data_importer.dart';
import '../../../domain/import/import_existing.dart';
import '../../../domain/import/import_issue.dart';
import '../../../domain/import/import_template.dart';
import '../../../domain/import/import_validator.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/file_delivery.dart';

/// Brings artists, products (with stock) and past sales in from the import
/// template, saved as one CSV file per tab. Everything is checked first;
/// nothing is imported while there is a problem.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final Map<ImportFileKind, PickedFile> _files = {};
  ImportCheck? _check;
  bool _busy = false;
  double? _progress;
  bool _skipAlreadyImported = false;

  static const _descriptions = {
    ImportFileKind.artists: 'Artists with billing details and commission.',
    ImportFileKind.products: 'Products, one row per variant, with today\'s stock.',
    ImportFileKind.pastSales: 'Every item of every receipt from the old till.',
  };

  Future<void> _choose(ImportFileKind kind) async {
    final file = await pickFile();
    if (file == null) return;
    setState(() {
      _files[kind] = file;
      _check = null;
    });
  }

  Future<void> _downloadTemplate() async {
    final data = await rootBundle.load(AppAssets.importTemplate);
    await deliverExport(
        ExportFile('Entre Sales - data import template.xlsx', data.buffer.asUint8List(), ExportFile.xlsx));
  }

  List<List<String>>? _rows(ImportFileKind kind) {
    final f = _files[kind];
    return f == null ? null : parseCsv(decodeCsvBytes(f.bytes));
  }

  Future<void> _runCheck() async {
    setState(() {
      _busy = true;
      _check = null;
      _skipAlreadyImported = false;
    });
    try {
      final artists = _rows(ImportFileKind.artists);
      final products = _rows(ImportFileKind.products);
      final sales = _rows(ImportFileKind.pastSales);

      final artistList = await ref.read(artistRepositoryProvider).artists();
      final productList = await ref.read(productRepositoryProvider).products();
      final existing = ImportExisting(
        artistNames: {for (final a in artistList) a.name.toLowerCase()},
        productKeys: {for (final p in productList) ImportExisting.productKey(p.artistName, p.name)},
        categories: await ref.read(categoryRepositoryProvider).categories(),
        discountNames: [for (final d in await ref.read(discountRepositoryProvider).discounts()) d.name],
        importedReceipts: sales == null
            ? const {}
            : await ref.read(importRepositoryProvider).importedReceipts(ImportValidator.receiptNumbers(sales)),
      );
      final check = ImportValidator.check(artists: artists, products: products, pastSales: sales, existing: existing);
      if (mounted) setState(() => _check = check);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not check the files: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport() async {
    final check = _check!;
    final plan = check.plan;
    final ok = await confirm(
      context,
      'Import now?',
      'This adds ${_planSummary(check)} to the live store. '
          'Past sales are added as history and do not change stock.',
      action: 'Import',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final summary = await DataImporter(ref.read(importRepositoryProvider))
          .run(plan, skipExisting: _skipAlreadyImported, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      refreshData(ref);
      if (!mounted) return;
      setState(() {
        _files.clear();
        _check = null;
      });
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import finished'),
          content: Text('Added $summary.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } on ImportRejectedException catch (e) {
      if (mounted) _showProblems('The database refused the import', e.problems);
    } catch (e) {
      if (mounted) {
        _showProblems('The import stopped', [
          '$e',
          'Anything already saved stays saved. Check the files again: receipts that made it in are '
              'listed as already imported, and can be skipped to finish the rest.',
        ]);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  void _showProblems(String title, List<String> problems) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: ctx.dialogWidth(AppSizes.dialogLarge),
            child: SingleChildScrollView(child: SelectableText(problems.join('\n'))),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  static String _planSummary(ImportCheck c) {
    final p = c.plan;
    return [
      if (p.artists.isNotEmpty) '${p.artists.length} artists',
      if (p.products.isNotEmpty) '${p.products.length} products (${p.variantCount} variants)',
      if (p.receipts.isNotEmpty) '${p.receipts.length} past receipts (${p.saleLineCount} items)',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = context.pagePadding;
    return Scaffold(
      appBar: AppBar(title: const Text('Import data')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, AppSpacing.m, pad, AppSpacing.xxl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.contentMax),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Fill in the import template, then save each tab (Artists, Products, Past sales) as a CSV file: '
                    'in Excel, open the tab → File → Save As → "CSV UTF-8". Choose the files below, check them, then import. '
                    'You can import just one or two of the files.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download the template'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  for (final kind in ImportFileKind.values) _fileCard(kind),
                  const SizedBox(height: AppSpacing.m),
                  Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy || _files.isEmpty ? null : _runCheck,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Check files'),
                      ),
                      if (_check != null)
                        FilledButton.icon(
                          onPressed: !_busy && _check!.canImport(skipAlreadyImported: _skipAlreadyImported)
                              ? _runImport
                              : null,
                          icon: const Icon(Icons.upload_outlined),
                          label: const Text('Import'),
                        ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: AppSpacing.m),
                    LinearProgressIndicator(value: _progress),
                  ],
                  if (_check != null) ...[
                    const SizedBox(height: AppSpacing.l),
                    _results(_check!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileCard(ImportFileKind kind) {
    final file = _files[kind];
    return Card(
      child: ListTile(
        leading: Icon(file == null ? Icons.description_outlined : Icons.check_circle,
            color: file == null ? null : context.appColors.success),
        title: Text(kind.label),
        subtitle: Text(file?.name ?? _descriptions[kind]!),
        trailing: Wrap(
          spacing: AppSpacing.xs,
          children: [
            if (file != null)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _files.remove(kind);
                          _check = null;
                        }),
              ),
            OutlinedButton(
              onPressed: _busy ? null : () => _choose(kind),
              child: Text(file == null ? 'Choose CSV' : 'Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(ImportCheck c) {
    final theme = Theme.of(context);
    final errors = c.errors;
    final already = c.alreadyImported;
    const shown = 200;

    Widget issueList(List<ImportIssue> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final i in list.take(shown))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: SelectableText('• $i'),
              ),
            if (list.length > shown) Text('…and ${list.length - shown} more.', style: theme.textTheme.bodySmall),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errors.isEmpty && already.isEmpty && !c.plan.isEmpty) ...[
              Row(children: [
                Icon(Icons.check_circle, color: context.appColors.success),
                const SizedBox(width: AppSpacing.s),
                Expanded(child: Text('Everything checks out.', style: theme.textTheme.titleMedium)),
              ]),
              const SizedBox(height: AppSpacing.s),
              Text('Ready to import ${_planSummary(c)}.'),
            ],
            if (errors.isNotEmpty) ...[
              Row(children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text('${errors.length} problem${errors.length == 1 ? '' : 's'} to fix',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                ),
              ]),
              const SizedBox(height: AppSpacing.xs),
              const Text('Nothing is imported until these are fixed. Correct them in the spreadsheet, save the CSV '
                  'again, choose it again and check.'),
              const SizedBox(height: AppSpacing.s),
              issueList(errors),
            ],
            if (already.isNotEmpty) ...[
              if (errors.isNotEmpty) const SizedBox(height: AppSpacing.l),
              Text('${already.length} receipt${already.length == 1 ? ' is' : 's are'} already in the store',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              const Text('If an earlier import was interrupted, these made it in. Tick below to import only the rest.'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _skipAlreadyImported,
                onChanged: (v) => setState(() => _skipAlreadyImported = v ?? false),
                title: const Text('Skip receipts already imported'),
              ),
              issueList(already),
            ],
          ],
        ),
      ),
    );
  }
}
