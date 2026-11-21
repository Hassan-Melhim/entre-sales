import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/product_category.dart';
import '../providers.dart';
import '../theme/app_tokens.dart';
import 'category_icon.dart';

/// A row of tabs, "All" plus one per category with its icon, used to filter
/// by category (Sell, Inventory, Sales). Scrolls sideways when the
/// categories don't fit.
class CategoryTabs extends ConsumerStatefulWidget {
  /// The chosen category; null = all.
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const CategoryTabs({super.key, required this.selectedId, required this.onChanged});

  @override
  ConsumerState<CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends ConsumerState<CategoryTabs> with TickerProviderStateMixin {
  TabController? _controller;
  List<int?> _ids = const [];

  int _indexOf(int? id) {
    final i = _ids.indexOf(id);
    return i < 0 ? 0 : i;
  }

  /// Makes a new controller when the categories change.
  TabController _sync(List<ProductCategory> categories) {
    final ids = <int?>[null, for (final c in categories) c.id];
    if (_controller == null || ids.length != _ids.length || !_sameIds(ids)) {
      _controller?.dispose();
      _ids = ids;
      _controller = TabController(length: ids.length, vsync: this, initialIndex: _indexOf(widget.selectedId));
    }
    return _controller!;
  }

  /// Follows a choice made elsewhere (e.g. the filter being reset).
  @override
  void didUpdateWidget(CategoryTabs old) {
    super.didUpdateWidget(old);
    final c = _controller;
    if (c != null && old.selectedId != widget.selectedId && c.index != _indexOf(widget.selectedId)) {
      c.index = _indexOf(widget.selectedId);
    }
  }

  bool _sameIds(List<int?> ids) {
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != _ids[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <ProductCategory>[];
    final controller = _sync(categories);
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      onTap: (i) => widget.onChanged(_ids[i]),
      tabs: [
        const _CategoryTab(icon: Icons.apps, label: 'All'),
        for (final c in categories) _CategoryTab(icon: CategoryIcon.iconFor(c.name), label: c.name),
      ],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CategoryTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Tab(
        height: AppSizes.categoryTabHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconMedium),
            const SizedBox(width: AppSpacing.s - AppSpacing.xxs),
            Text(label),
          ],
        ),
      );
}
