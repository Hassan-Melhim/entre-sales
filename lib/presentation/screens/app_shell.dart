import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../staff_accounts.dart';

import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';
import '../widgets/backup_banner.dart';
import '../widgets/staff_avatar.dart';
import 'artists/artists_screen.dart';
import 'inventory/inventory_screen.dart';
import 'invoices/invoices_screen.dart';
import 'pos/pos_screen.dart';
import 'reports/reports_screen.dart';
import 'sales/sales_screen.dart';
import 'settings/settings_screen.dart';

/// Main navigation, adapted to the screen:
/// - phones / narrow windows: top bar with a menu drawer
/// - iPad portrait: navigation rail (icons + labels)
/// - iPad landscape / laptops: extended rail with labels beside icons
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;
  const _Destination(this.label, this.icon, this.selectedIcon, this.build);
}

class _AppShellState extends ConsumerState<AppShell> {
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

  Future<void> _signOut() => signOutThisDevice(ref);

  /// Who is signed in (name and icon for staff, else the email), with a
  /// sign-out button.
  Widget _account(BuildContext context, {required bool compact}) {
    final email = ref.watch(currentUserProvider).valueOrNull?.email ?? '';
    final staff = staffFor(email);
    final who = staff?.name ?? email;
    final index = staff == null ? 0 : staffAccounts.indexOf(staff);
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Column(
          children: [
            Tooltip(message: who, child: StaffAvatar(staff, colorIndex: index, size: AppSizes.avatarSmall)),
            IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: _signOut),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: SizedBox(
        width: AppSizes.railExtendedWidth - 2 * AppSpacing.m,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StaffAvatar(staff, colorIndex: index, size: AppSizes.avatarSmall),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: Text(who, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall)),
            ]),
            TextButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('Sign out')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The backup reminder sits above every page.
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const BackupBanner(), Expanded(child: _destinations[_index].build())],
    );

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
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl + AppSpacing.xs, AppSpacing.l + AppSpacing.xs,
                  AppSpacing.l, AppSpacing.m),
              child: _brand(context),
            ),
            for (final d in _destinations)
              NavigationDrawerDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            const Divider(),
            _account(context, compact: false),
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
            Column(
              children: [
                Expanded(
                  // Scrollable so the rail never overflows on short screens.
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            selectedIndex: _index,
                            onDestinationSelected: _select,
                            extended: extended,
                            minExtendedWidth: AppSizes.railExtendedWidth,
                            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                              child: _brand(context),
                            ),
                            destinations: [
                              for (final d in _destinations)
                                NavigationRailDestination(
                                    icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _account(context, compact: !extended),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }
}
