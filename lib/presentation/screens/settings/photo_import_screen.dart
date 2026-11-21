import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/files/browser_folder_picker.dart';
import '../../../data/files/photo_shrinker.dart';
import '../../../domain/models/product.dart';
import '../../../domain/photos/photo_matcher.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/dialogs.dart';

/// Gives many products their photo at once, from a folder laid out like the
/// Google Drive: `Category / Product name - Artist name / images`.
///
/// Choose the folder → see what matches → import. Each photo is shrunk in
/// the browser before it is uploaded; the originals are never sent.
class PhotoImportScreen extends ConsumerStatefulWidget {
  const PhotoImportScreen({super.key});

  @override
  ConsumerState<PhotoImportScreen> createState() => _PhotoImportScreenState();
}

class _PhotoImportScreenState extends ConsumerState<PhotoImportScreen> {
  /// Photos are prepared and uploaded this many at a time.
  static const _parallel = 3;

  List<FolderFile>? _files;
  Map<String, FolderFile> _byPath = {};
  List<Product> _products = [];
  PhotoPlan? _plan;
  bool _replaceExisting = false;
  bool _loading = false;
  String? _folderProblem;

  // While importing.
  bool _running = false;
  bool _stopRequested = false;
  int _done = 0;
  int _total = 0;
  final List<String> _failures = [];
  bool _finished = false;

  Future<void> _chooseFolder() async {
    final files = await pickFolder();
    if (files == null || !mounted) return;
    setState(() {
      _loading = true;
      _plan = null;
      _finished = false;
      _failures.clear();
      _folderProblem = null;
    });
    try {
      final products = await ref.read(productRepositoryProvider).products();
      if (!mounted) return;
      _files = files;
      _byPath = {for (final f in files) f.path.replaceAll('\\', '/'): f};
      _products = products;
      if (!files.any((f) => f.path.contains('/'))) {
        _folderProblem = 'This browser did not give the folder names, so photos can\'t be matched to products. '
            'Choosing a folder works on a Mac or PC (Chrome or Safari), not on the iPad.';
      }
      _replan();
    } catch (e) {
      if (mounted) showMessage(context, 'Could not load the products: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replan() {
    final files = _files;
    if (files == null) return;
    setState(() => _plan = PhotoMatcher.plan(_byPath.keys.toList(), _products, replaceExisting: _replaceExisting));
  }

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null || plan.matches.isEmpty) return;
    if (!await confirm(
        context,
        'Import ${plan.matches.length} photo${plan.matches.length == 1 ? '' : 's'}?',
        'Keep this page open until it finishes. You can stop at any time; photos already added stay.',
        action: 'Import')) {
      return;
    }
    setState(() {
      _running = true;
      _stopRequested = false;
      _finished = false;
      _done = 0;
      _total = plan.matches.length;
      _failures.clear();
    });
    final photos = ref.read(productPhotoRepositoryProvider);
    final queue = List.of(plan.matches);

    Future<void> worker() async {
      while (queue.isNotEmpty && !_stopRequested) {
        final m = queue.removeAt(0);
        final file = _byPath[m.file];
        try {
          if (file == null) throw StateError('file not found');
          final pair = await shrinkPhoto(file.file, fileName: file.file.name);
          await photos.setPhoto(m.product.id!, pair, previous: m.product);
        } catch (e) {
          _failures.add('${m.product.name} (${m.product.artistName}) ← ${m.file}: $e');
        }
        if (mounted) setState(() => _done++);
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    refreshData(ref);
    if (!mounted) return;
    // Show the new state: the products that got a photo now count as having one.
    try {
      _products = await ref.read(productRepositoryProvider).products();
    } catch (_) {
      // The lists below are then slightly out of date; nothing else is affected.
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _finished = true;
    });
    _replan();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = context.pagePadding;
    return PopScope(
      canPop: !_running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showMessage(context, 'Stop the import first, or wait until it finishes.');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Import photos')),
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
                      'Choose the folder that holds the category folders: the Google Drive download (unzipped) '
                      'or the Drive folder in Google Drive for desktop. Inside each category, a folder named '
                      '"Product name - Artist name" gives that product its photo: the first image in it, '
                      'sorted by name. Use a Mac or PC: the iPad can\'t choose folders.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Photos are shrunk on this computer before upload (1200 px, plus a small copy for lists). '
                      'HEIC photos open in Safari, not in Chrome.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _running || _loading ? null : _chooseFolder,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: Text(_files == null ? 'Choose folder' : 'Choose another folder'),
                        ),
                        if (_plan != null && !_running)
                          FilledButton.icon(
                            onPressed: _plan!.matches.isEmpty || _folderProblem != null ? null : _import,
                            icon: const Icon(Icons.upload_outlined),
                            label: Text('Import ${_plan!.matches.length} photo${_plan!.matches.length == 1 ? '' : 's'}'),
                          ),
                        if (_running)
                          OutlinedButton.icon(
                            onPressed: _stopRequested ? null : () => setState(() => _stopRequested = true),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(_stopRequested ? 'Stopping…' : 'Stop'),
                          ),
                      ],
                    ),
                    if (_loading) ...[
                      const SizedBox(height: AppSpacing.m),
                      const LinearProgressIndicator(),
                    ],
                    if (_running) ...[
                      const SizedBox(height: AppSpacing.m),
                      LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
                      const SizedBox(height: AppSpacing.xs),
                      Text('$_done of $_total done'
                          '${_failures.isEmpty ? '' : ' · ${_failures.length} failed'}'),
                    ],
                    if (_finished) ...[
                      const SizedBox(height: AppSpacing.l),
                      _finishedCard(),
                    ],
                    if (_folderProblem != null) ...[
                      const SizedBox(height: AppSpacing.l),
                      _notice(Icons.error_outline, theme.colorScheme.error, _folderProblem!),
                    ],
                    if (_plan != null && _folderProblem == null && !_running) ...[
                      const SizedBox(height: AppSpacing.l),
                      _planCard(_plan!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(IconData icon, Color color, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(text)),
        ],
      );

  Widget _finishedCard() {
    final added = _done - _failures.length;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _notice(
              _failures.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
              _failures.isEmpty ? context.appColors.success : context.appColors.warning,
              '$added photo${added == 1 ? '' : 's'} added'
              '${_failures.isEmpty ? '' : ', ${_failures.length} failed'}'
              '${_done < _total ? ' (stopped before the end)' : ''}.',
            ),
            if (_failures.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Text('These were not added. Import again to retry them: products that have a photo now are skipped.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              _lines(_failures),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planCard(PhotoPlan plan) {
    final theme = Theme.of(context);
    String s(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What this folder gives', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s),
            _group(
              icon: Icons.add_photo_alternate_outlined,
              color: context.appColors.success,
              title: '${s(plan.matches.length, 'product gets', 'products get')} a photo',
              lines: [for (final m in plan.matches) '${m.product.name} (${m.product.artistName}) ← ${m.file}'],
            ),
            if (plan.alreadyHavePhoto.isNotEmpty || _replaceExisting)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _replaceExisting,
                onChanged: (v) {
                  _replaceExisting = v ?? false;
                  _replan();
                },
                title: Text(_replaceExisting
                    ? 'Replace photos products already have'
                    : '${s(plan.alreadyHavePhoto.length, 'product already has', 'products already have')} '
                        'a photo and will be left alone. Tick to replace them too.'),
              ),
            _group(
              icon: Icons.folder_off_outlined,
              color: context.appColors.warning,
              title: '${s(plan.unmatchedFolders.length, 'folder matches', 'folders match')} no product',
              help: 'Check that the folder is named "Product name - Artist name", spelled as in the inventory. '
                  'Rename it, then choose the folder again.',
              lines: plan.unmatchedFolders,
            ),
            _group(
              icon: Icons.image_not_supported_outlined,
              color: theme.colorScheme.outline,
              title: '${s(plan.productsWithoutPhoto.length, 'product has', 'products have')} no photo folder',
              help: 'They show their category icon. Add their photos to the Drive later and import again, '
                  'or add one in the product form.',
              lines: [for (final p in plan.productsWithoutPhoto) '${p.name} (${p.artistName}) · ${p.categoryName}'],
            ),
            if (plan.ignoredFiles > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s),
                child: Text('${s(plan.ignoredFiles, 'file was', 'files were')} skipped (not images, or hidden).',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _group({
    required IconData icon,
    required Color color,
    required String title,
    String? help,
    required List<String> lines,
  }) {
    if (lines.isEmpty) {
      return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: color), title: Text(title));
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: help == null ? null : Text(help),
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.m),
      children: [_lines(lines)],
    );
  }

  Widget _lines(List<String> lines) {
    const shown = 300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in lines.take(shown))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: SelectableText('• $l'),
          ),
        if (lines.length > shown)
          Text('…and ${lines.length - shown} more.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
