import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/business_rules.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../common.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Artists',
          actions: [
            FilledButton.icon(
              onPressed: () => showArtistForm(context, ref),
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
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = filtered[i];
                  return ListTile(
                    title: Text(a.name),
                    subtitle: Text([
                      if (a.gender != null) a.gender!,
                      'Commission ${formatPercent(a.effectiveCommission)}${a.commissionPercent == null ? ' (default)' : ''}',
                      a.isSpainResident ? 'Spain resident' : 'Non-resident',
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showArtistForm(context, ref, artist: a),
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

/// Opens the create/edit artist dialog. Returns the saved artist id.
Future<int?> showArtistForm(BuildContext context, WidgetRef ref, {Artist? artist}) {
  return showDialog<int>(context: context, builder: (_) => _ArtistForm(artist: artist));
}

class _ArtistForm extends ConsumerStatefulWidget {
  final Artist? artist;
  const _ArtistForm({this.artist});

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

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label, {String? hint, bool isRequired = false, String? Function(String?)? validator}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            decoration: InputDecoration(labelText: label, hintText: hint),
            validator: validator ?? (isRequired ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
          ),
        );

    return AlertDialog(
      title: Text(widget.artist == null ? 'New artist' : 'Edit artist'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                field(_name, 'Name *', isRequired: true),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: 'Gender (for sales analysis)'),
                    items: [
                      for (final g in BusinessRules.genders) DropdownMenuItem(value: g, child: Text(g)),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                ),
                field(_address, 'Address'),
                Text('Billing', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                field(_legalName, 'Legal name'),
                field(_taxId, 'Tax ID (NIF / NIE)'),
                field(_iban, 'IBAN'),
                field(_bank, 'Bank'),
                Text('Payment terms', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                field(
                  _commission,
                  'Store commission %',
                  hint: 'Leave empty for the default ${formatPercent(BusinessRules.defaultCommissionPercent)}',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty || parsePercent(v) != null) ? null : 'Enter a number from 0 to 100',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resides in Spain'),
                  subtitle: Text(
                      '${BusinessRules.residentTaxAddedOnTop ? 'Adds' : 'Withholds'} ${formatPercent(BusinessRules.spainResidentArtistTaxPercent)} tax on payouts'),
                  value: _resident,
                  onChanged: (v) => setState(() => _resident = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.artist != null)
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
