import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/business_rules.dart';
import '../../core/money.dart';
import '../../models/artist.dart';
import '../../providers.dart';
import '../common.dart';
import '../responsive.dart';

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final artists = ref.watch(artistsProvider);
    final pad = context.pagePadding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Artists',
          actions: [
            FilledButton.icon(
              onPressed: () => showArtistForm(context),
              icon: const Icon(Icons.add),
              label: const Text('New artist'),
            ),
          ],
          bottom: SearchField(hint: 'Search artists', onChanged: (v) => setState(() => _query = v)),
        ),
        Expanded(
          child: AsyncView(
            value: artists,
            builder: (list) {
              final q = _query.toLowerCase();
              final filtered = list.where((a) => a.name.toLowerCase().contains(q)).toList();
              if (filtered.isEmpty) {
                return const EmptyState(icon: Icons.palette_outlined, message: 'No artists yet');
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = filtered[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.name),
                    subtitle: Text([
                      if (a.gender != null) a.gender!,
                      'Commission ${formatPercent(a.effectiveCommission)}${a.commissionPercent == null ? ' (default)' : ''}',
                      a.isSpainResident ? 'Spain resident' : 'Non-resident',
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showArtistForm(context, artist: a),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Opens the create/edit artist form. Returns the saved artist id.
/// Full screen on phones, a dialog on larger screens.
Future<int?> showArtistForm(BuildContext context, {Artist? artist}) {
  if (context.isCompact) {
    return Navigator.push<int>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _ArtistForm(artist: artist, fullScreen: true)),
    );
  }
  return showDialog<int>(context: context, builder: (_) => _ArtistForm(artist: artist, fullScreen: false));
}

class _ArtistForm extends ConsumerStatefulWidget {
  final Artist? artist;
  final bool fullScreen;
  const _ArtistForm({this.artist, required this.fullScreen});

  @override
  ConsumerState<_ArtistForm> createState() => _ArtistFormState();
}

class _ArtistFormState extends ConsumerState<_ArtistForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.artist?.name);
  late final _address = TextEditingController(text: widget.artist?.address);
  late final _legalName = TextEditingController(text: widget.artist?.legalName);
  late final _taxId = TextEditingController(text: widget.artist?.taxId);
  late final _iban = TextEditingController(text: widget.artist?.iban);
  late final _bank = TextEditingController(text: widget.artist?.bankName);
  late final _commission = TextEditingController(
      text: widget.artist?.commissionPercent == null ? '' : widget.artist!.commissionPercent!.toString());
  late String? _gender = widget.artist?.gender;
  late bool _resident = widget.artist?.isSpainResident ?? true;

  String get _title => widget.artist == null ? 'New artist' : 'Edit artist';

  @override
  void dispose() {
    for (final c in [_name, _address, _legalName, _taxId, _iban, _bank, _commission]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final artist = Artist(
      id: widget.artist?.id,
      name: _name.text.trim(),
      gender: _gender,
      address: t(_address),
      legalName: t(_legalName),
      taxId: t(_taxId),
      iban: t(_iban)?.replaceAll(' ', '').toUpperCase(),
      bankName: t(_bank),
      isSpainResident: _resident,
      commissionPercent: _commission.text.trim().isEmpty ? null : parsePercent(_commission.text),
    );
    final id = await ref.read(inventoryRepoProvider).saveArtist(artist);
    refreshData(ref);
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _delete() async {
    final repo = ref.read(inventoryRepoProvider);
    final id = widget.artist!.id!;
    if (!await repo.canDeleteArtist(id)) {
      if (mounted) showMessage(context, 'This artist has products or sales and cannot be deleted.', error: true);
      return;
    }
    if (!mounted) return;
    if (!await confirm(context, 'Delete artist?', 'This cannot be undone.', action: 'Delete')) return;
    await repo.deleteArtist(id);
    refreshData(ref);
    if (mounted) Navigator.pop(context);
  }

  Widget _field(TextEditingController c, String label,
          {String? hint, bool isRequired = false, String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: validator ?? (isRequired ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
        ),
      );

  Widget _fields(BuildContext context) => Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            _field(_name, 'Name *', isRequired: true),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: _gender,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Gender (for sales analysis)'),
                items: [for (final g in BusinessRules.genders) DropdownMenuItem(value: g, child: Text(g))],
                onChanged: (v) => setState(() => _gender = v),
              ),
            ),
            _field(_address, 'Address'),
            Text('Billing', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _field(_legalName, 'Legal name'),
            _field(_taxId, 'Tax ID (NIF / NIE)'),
            _field(_iban, 'IBAN'),
            _field(_bank, 'Bank'),
            Text('Payment terms', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _field(
              _commission,
              'Store commission %',
              hint: 'Empty = default ${formatPercent(BusinessRules.defaultCommissionPercent)}',
              validator: (v) =>
                  (v == null || v.trim().isEmpty || parsePercent(v) != null) ? null : 'Enter a number from 0 to 100',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Resides in Spain'),
              subtitle: Text('${BusinessRules.residentTaxAddedOnTop ? 'Adds' : 'Withholds'} '
                  '${formatPercent(BusinessRules.spainResidentArtistTaxPercent)} tax on payouts'),
              value: _resident,
              onChanged: (v) => setState(() => _resident = v),
            ),
          ],
        ),
      );

  Widget? _deleteButton(BuildContext context) => widget.artist == null
      ? null
      : TextButton(
          onPressed: _delete,
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Delete'),
        );

  @override
  Widget build(BuildContext context) {
    final delete = _deleteButton(context);

    if (widget.fullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            if (delete != null) delete,
            TextButton(onPressed: _save, child: const Text('Save')),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _fields(context)),
        ),
      );
    }

    return AlertDialog(
      title: Text(_title),
      content: SizedBox(width: context.dialogWidth(560), child: SingleChildScrollView(child: _fields(context))),
      actions: [
        if (delete != null) delete,
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
