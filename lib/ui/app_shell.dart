import 'package:flutter/material.dart';

import 'artists/artists_screen.dart';
import 'inventory/inventory_screen.dart';
import 'invoices/invoices_screen.dart';
import 'pos/pos_screen.dart';
import 'reports/reports_screen.dart';
import 'responsive.dart';
import 'sales/sales_screen.dart';
import 'settings/settings_screen.dart';

/// Main navigation, adapted to the screen:
/// - phones: top app bar with a menu drawer
/// - tablets in portrait: navigation rail (icons + labels)
/// - tablets in landscape / computers: extended rail with labels beside icons
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;
  const _Destination(this.label, this.icon, this.selectedIcon, this.build);
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static final _destinations = <_Destination>[
    _Destination('Sell', Icons.point_of_sale_outlined, Icons.point_of_sale, () => const PosScreen()),
    _Destination('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, () => const InventoryScreen()),
    _Destination('Artists', Icons.palette_outlined, Icons.palette, () => const ArtistsScreen()),
    _Destination('Sales', Icons.receipt_long_outlined, Icons.receipt_long, () => const SalesScreen()),
    _Destination('Invoices', Icons.request_quote_outlined, Icons.request_quote, () => const InvoicesScreen()),
    _Destination('Reports', Icons.insights_outlined, Icons.insights, () => const ReportsScreen()),
    _Destination('Settings', Icons.settings_outlined, Icons.settings, () => const SettingsScreen()),
  ];

  void _select(int i) => setState(() => _index = i);

  Widget _brand(BuildContext context) => Text(
        'entre',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
      );

  @override
  Widget build(BuildContext context) {
    final page = _destinations[_index].build();

    if (context.isCompact) {
      return Scaffold(
        // Each page shows its own title, so the bar only carries the brand.
        appBar: AppBar(title: _brand(context), centerTitle: false),
        drawer: NavigationDrawer(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            Navigator.pop(context); // close the drawer
            _select(i);
          },
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(28, 20, 16, 12), child: _brand(context)),
            for (final d in _destinations)
              NavigationDrawerDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(d.label),
              ),
          ],
        ),
        body: SafeArea(top: false, child: page),
      );
    }

    final extended = context.isExpanded;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Scrollable so the rail never overflows on short screens.
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: _select,
                      extended: extended,
                      minExtendedWidth: 180,
                      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                      leading: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: _brand(context)),
                      destinations: [
                        for (final d in _destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }
}
