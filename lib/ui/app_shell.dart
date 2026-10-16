import 'package:flutter/material.dart';

import 'artists/artists_screen.dart';
import 'inventory/inventory_screen.dart';
import 'invoices/invoices_screen.dart';
import 'pos/pos_screen.dart';
import 'reports/reports_screen.dart';
import 'sales/sales_screen.dart';
import 'settings/settings_screen.dart';

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

  final _destinations = <_Destination>[
    _Destination('Sell', Icons.point_of_sale_outlined, Icons.point_of_sale, () => const PosScreen()),
    _Destination('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, () => const InventoryScreen()),
    _Destination('Artists', Icons.palette_outlined, Icons.palette, () => const ArtistsScreen()),
    _Destination('Sales', Icons.receipt_long_outlined, Icons.receipt_long, () => const SalesScreen()),
    _Destination('Invoices', Icons.request_quote_outlined, Icons.request_quote, () => const InvoicesScreen()),
    _Destination('Reports', Icons.insights_outlined, Icons.insights, () => const ReportsScreen()),
    _Destination('Settings', Icons.settings_outlined, Icons.settings, () => const SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('entre',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _destinations[_index].build()),
          ],
        ),
      ),
    );
  }
}
