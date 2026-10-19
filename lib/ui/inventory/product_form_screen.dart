import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/pricing.dart';
import '../../models/artist.dart';
import '../../models/category_attribute.dart';
import '../../models/product_category.dart';
import '../../models/variant.dart';
import '../../providers.dart';
import '../artists/artists_screen.dart';
import '../common.dart';
import '../responsive.dart';

/// Log a new product, or edit an existing one.
///
/// Flow: name → artist → delivery date → category. Choosing a category shows
/// its fields (e.g. Size, Language). Every combination of the chosen values
/// becomes a variant with its own quantity (and price, if enabled).
class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

/// Form state for one variant row (text controllers live here).
class _VariantRow {
  final int? id;
  final Map<String, String> attributes;
  final TextEditingController quantity;
  final TextEditingController price;
  final int originalQuantity;
  final DateTime? originalArrival;

  _VariantRow({
    this.id,
    required this.attributes,
    required int quantity,
    String price = '',
    this.originalArrival,
  })  : quantity = TextEditingController(text: '$quantity'),
        price = TextEditingController(text: price),
        originalQuantity = id == null ? 0 : quantity;

  String get label => Variant.labelFor(attributes);

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _tax = TextEditingController();

  bool _loading = true;
  int? _artistId;
  ProductCategory? _category;
  DateTime _deliveryDate = DateTime.now();
  bool _perVariantPricing = false;
  bool _customTax = false;

  /// Attribute name → values chosen for this product.
  final Map<String, List<String>> _values = {};

  /// Attribute name → controller for typing a new free-text value.
  final Map<String, TextEditingController> _freeText = {};

  /// Variant key → row. Rows survive while the combination still exists.
  final Map<String, _VariantRow> _rows = {};

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final repo = ref.read(inventoryRepoProvider);
      final p = await repo.product(widget.productId!);
      final cats = await repo.categories();
      if (p != null) {
        _name.text = p.name;
        _price.text = centsToInput(p.basePriceCents);
        _artistId = p.artistId;
        _category = cats.firstWhere((c) => c.id == p.categoryId);
        _perVariantPricing = p.perVariantPricing;
        _customTax = p.taxPercentOverride != null;
        if (_customTax) _tax.text = p.taxPercentOverride.toString();
        for (final v in p.variants) {
          v.attributes.forEach((k, val) {
            final list = _values.putIfAbsent(k, () => []);
            if (!list.contains(val)) list.add(val);
          });
          _rows[_key(v.attributes)] = _VariantRow(
            id: v.id,
            attributes: v.attributes,
            quantity: v.quantity,
            price: v.priceOverrideCents == null ? '' : centsToInput(v.priceOverrideCents!),
            originalArrival: v.dateOfArrival,
          );
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _tax.dispose();
    for (final c in _freeText.values) {
      c.dispose();
    }
    for (final r in _rows.values) {
      r.dispose();
    }
    super.dispose();
  }

  String _key(Map<String, String> attrs) {
    final sorted = Map.fromEntries(attrs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return jsonEncode(sorted);
  }

  /// All combinations of the chosen values, in category attribute order.
  /// Attributes with no chosen value are left out.
  List<Map<String, String>> _combinations() {
    var combos = <Map<String, String>>[{}];
    for (final attr in _category?.attributes ?? const <CategoryAttribute>[]) {
      final vals = _values[attr.name] ?? const [];
      if (vals.isEmpty) continue;
      combos = [
        for (final c in combos)
          for (final v in vals) {...c, attr.name: v},
      ];
    }
    return combos;
  }

  /// Rows for the current combinations; creates new rows as needed.
  List<_VariantRow> _currentRows() => [
        for (final combo in _combinations())
          _rows.putIfAbsent(_key(combo), () => _VariantRow(attributes: combo, quantity: 0)),
      ];

  void _onCategoryChanged(ProductCategory c) {
    setState(() {
      _category = c;
      _values.removeWhere((k, _) => !c.attributes.any((a) => a.name == k));
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_artistId == null || _category == null) {
      showMessage(context, 'Choose an artist and a category', error: true);
      return;
    }
    final rows = _currentRows();
    final base = parseEurosToCents(_price.text)!;

    final variants = <Variant>[];
    for (final r in rows) {
      final q = int.tryParse(r.quantity.text.trim());
      if (q == null || q < 0) {
        showMessage(context, 'Quantity for "${r.label}" must be a whole number', error: true);
        return;
      }
      int? priceOverride;
      if (_perVariantPricing && r.price.text.trim().isNotEmpty) {
        priceOverride = parseEurosToCents(r.price.text);
        if (priceOverride == null) {
          showMessage(context, 'Price for "${r.label}" is not valid', error: true);
          return;
        }
      }
      // New variants and added stock take the delivery date (a restock
      // overwrites the date of arrival). Otherwise the old date is kept.
      final arrival =
          (r.id == null || q > r.originalQuantity) ? _deliveryDate : (r.originalArrival ?? _deliveryDate);
      variants.add(Variant(
        id: r.id,
        attributes: r.attributes,
        quantity: q,
        priceOverrideCents: priceOverride,
        dateOfArrival: arrival,
      ));
    }

    await ref.read(inventoryRepoProvider).saveProduct(
          id: widget.productId,
          name: _name.text.trim(),
          artistId: _artistId!,
          categoryId: _category!.id!,
          basePriceCents: base,
          perVariantPricing: _perVariantPricing,
          taxPercentOverride: _customTax ? parsePercent(_tax.text) : null,
          variants: variants,
        );
    refreshData(ref);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final repo = ref.read(inventoryRepoProvider);
    if (!await repo.canDeleteProduct(widget.productId!)) {
      if (mounted) {
        showMessage(context, 'This product has sales, so it is kept for history. Set its stock to 0 instead.',
            error: true);
      }
      return;
    }
    if (!mounted) return;
    if (!await confirm(context, 'Delete product?', 'This cannot be undone.', action: 'Delete')) return;
    await repo.deleteProduct(widget.productId!);
    refreshData(ref);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final artists = ref.watch(artistsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    // Keep the selected category object in sync with the latest list.
    if (_category != null) {
      final fresh = categories.where((c) => c.id == _category!.id);
      if (fresh.isNotEmpty) _category = fresh.first;
    }
    final pad = context.pagePadding;
    final compact = context.isCompact;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit product' : 'Log new product'),
        actions: [
          if (_isEdit)
            compact
                ? IconButton(
                    tooltip: 'Delete',
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  )
                : TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    child: const Text('Delete'),
                  ),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save')),
          SizedBox(width: pad),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  // Keeps the form readable on very wide screens.
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section('1. Product'),
                          _productFields(artists),
                          const SizedBox(height: 24),
                          _section('2. Category'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in categories)
                                ChoiceChip(
                                  label: Text(c.name),
                                  selected: _category?.id == c.id,
                                  onSelected: (_) => _onCategoryChanged(c),
                                ),
                            ],
                          ),
                          if (_category != null) ...[
                            const SizedBox(height: 16),
                            ..._category!.attributes.map(_attributeEditor),
                            if (_category!.attributes.isEmpty)
                              Text('This category has no extra fields. Add some in Settings → Categories.',
                                  style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                            const SizedBox(height: 24),
                            _section('3. Price'),
                            _priceSection(),
                            const SizedBox(height: 24),
                            _section('4. Quantities'),
                            _variantTable(),
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _productFields(List<Artist> artists) {
    return ResponsiveFields(
      minRowWidth: 760,
      flex: const [3, 3, 2],
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Product name *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: artists.any((a) => a.id == _artistId) ? _artistId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Artist *'),
                items: [for (final a in artists) DropdownMenuItem(value: a.id!, child: Text(a.name))],
                onChanged: (v) => setState(() => _artistId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            IconButton(
              tooltip: 'New artist',
              icon: const Icon(Icons.person_add_alt),
              onPressed: () async {
                final id = await showArtistForm(context);
                if (id != null) setState(() => _artistId = id);
              },
            ),
          ],
        ),
        InkWell(
          onTap: () async {
            final d = await pickDate(context, _deliveryDate);
            if (d != null) setState(() => _deliveryDate = d);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: _isEdit ? 'Restock date (for added units)' : 'Date of delivery *',
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(formatDate(_deliveryDate)),
          ),
        ),
      ],
    );
  }

  Widget _attributeEditor(CategoryAttribute attr) {
    final chosen = _values.putIfAbsent(attr.name, () => []);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(attr.name, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (!attr.isFreeText)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in attr.options)
                  FilterChip(
                    label: Text(o),
                    selected: chosen.contains(o),
                    onSelected: (sel) => setState(() => sel ? chosen.add(o) : chosen.remove(o)),
                  ),
                // Values from older products that are not in the list any more.
                for (final o in chosen.where((c) => !attr.options.contains(c)).toList())
                  FilterChip(label: Text(o), selected: true, onSelected: (_) => setState(() => chosen.remove(o))),
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in chosen) InputChip(label: Text(v), onDeleted: () => setState(() => chosen.remove(v))),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: _freeText.putIfAbsent(attr.name, () => TextEditingController()),
                decoration: InputDecoration(
                  hintText: 'Type a ${attr.name.toLowerCase()} and press enter (comma for several)',
                  suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _addFreeText(attr.name)),
                ),
                onSubmitted: (_) => _addFreeText(attr.name),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addFreeText(String attrName) {
    final c = _freeText[attrName]!;
    final parts = c.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    setState(() {
      final list = _values.putIfAbsent(attrName, () => []);
      for (final p in parts) {
        if (!list.any((x) => x.toLowerCase() == p.toLowerCase())) list.add(p);
      }
      c.clear();
    });
  }

  Widget _priceSection() {
    final base = parseEurosToCents(_price.text);
    final tax = _customTax ? (parsePercent(_tax.text) ?? _category!.taxPercent) : _category!.taxPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price before tax (€) *'),
                onChanged: (_) => setState(() {}),
                validator: (v) => parseEurosToCents(v ?? '') == null ? 'Enter a price' : null,
              ),
            ),
            Text(
              base == null
                  ? 'Tax ${formatPercent(tax)}'
                  : '+ ${formatPercent(tax)} tax = ${formatCents(Pricing.unitPriceWithTax(base, tax))} on the shelf',
            ),
          ],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Different price per variant'),
          subtitle: const Text('e.g. a poster that costs more in a bigger size'),
          value: _perVariantPricing,
          onChanged: (v) => setState(() => _perVariantPricing = v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Custom tax rate for this product'),
          subtitle: Text('Category rate is ${formatPercent(_category!.taxPercent)}'),
          value: _customTax,
          onChanged: (v) => setState(() => _customTax = v ?? false),
        ),
        if (_customTax)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: SizedBox(
              width: 160,
              child: TextFormField(
                controller: _tax,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tax %'),
                onChanged: (_) => setState(() {}),
                validator: (v) => _customTax && parsePercent(v ?? '') == null ? 'Enter 0–100' : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _quantityField(_VariantRow r) => TextField(
        controller: r.quantity,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Quantity'),
      );

  Widget _priceField(_VariantRow r) => TextField(
        controller: r.price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Price before tax (€)',
          hintText: _price.text.isEmpty ? null : 'Default ${_price.text}',
        ),
      );

  Widget _variantTable() {
    final rows = _currentRows();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 520;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_category!.attributes.isNotEmpty && _combinations().first.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('No ${_category!.attributes.map((a) => a.name.toLowerCase()).join(' / ')} chosen: '
                      'the product is logged as a single standard item.'),
                ),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: wide
                      // Wide: label | quantity | price on one line.
                      ? Row(
                          children: [
                            Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w500))),
                            SizedBox(width: 120, child: _quantityField(r)),
                            if (_perVariantPricing) ...[
                              const SizedBox(width: 12),
                              SizedBox(width: 200, child: _priceField(r)),
                            ],
                          ],
                        )
                      // Narrow: label above, fields share the width.
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(r.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: _quantityField(r)),
                                if (_perVariantPricing) ...[
                                  const SizedBox(width: 12),
                                  Expanded(flex: 2, child: _priceField(r)),
                                ],
                              ],
                            ),
                          ],
                        ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
