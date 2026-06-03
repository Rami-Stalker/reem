import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final location = GoRouterState.of(context).uri.path;

    final destinations = [
      _AdminNavItem(
        path: RoutePaths.admin,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: l10n.adminDashboard,
      ),
      _AdminNavItem(
        path: RoutePaths.adminOrders,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.adminOrders,
      ),
      _AdminNavItem(
        path: RoutePaths.adminProducts,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: l10n.adminProducts,
      ),
      _AdminNavItem(
        path: RoutePaths.adminUsers,
        icon: Icons.people_outline,
        selectedIcon: Icons.people_rounded,
        label: l10n.adminUsers,
      ),
      _AdminNavItem(
        path: RoutePaths.adminAnalytics,
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        label: l10n.adminAnalytics,
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width > 900,
            backgroundColor: colors.surface,
            selectedIndex: _selectedIndex(location, destinations),
            onDestinationSelected: (index) {
              context.go(destinations[index].path);
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.lg),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: DsRadius.borderMd,
                    ),
                    child: Icon(Icons.storefront_rounded, color: colors.primary),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Text(
                    l10n.adminPanel,
                    style: TextStyle(
                      fontSize: DsTypography.labelSmall,
                      fontWeight: DsTypography.semiBold,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.lg),
                  child: IconButton(
                    tooltip: l10n.adminBackToShop,
                    onPressed: () => context.go(RoutePaths.home),
                    icon: Icon(Icons.arrow_back_rounded, color: colors.primary),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final item in destinations)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String path, List<_AdminNavItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (path == items[i].path) return i;
    }
    return 0;
  }
}

class _AdminNavItem {
  const _AdminNavItem({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
