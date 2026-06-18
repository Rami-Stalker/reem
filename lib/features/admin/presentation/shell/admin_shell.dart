import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/experience/role_experience.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final path = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final destinations = AppRoleExperience.admin.navigation
        .map(_AdminNavItem.fromRoleNavigation)
        .toList(growable: false);

    if (width < 720) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(l10n.adminPanel),
          actions: [
            IconButton(
              tooltip: 'Administrator settings',
              onPressed: () => context.go(RoutePaths.adminSystemSettings),
              icon: const Icon(Icons.admin_panel_settings_rounded),
            ),
          ],
        ),
        drawer: Drawer(
          child: _AdminNavigation(
            destinations: destinations,
            selectedPath: path,
            extended: true,
          ),
        ),
        body: child,
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          _AdminNavigation(
            destinations: destinations,
            selectedPath: path,
            extended: width >= 1100,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.destinations,
    required this.selectedPath,
    required this.extended,
  });

  final List<_AdminNavItem> destinations;
  final String selectedPath;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      width: extended ? 260 : 88,
      color: colors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.md,
                DsSpacing.lg,
                DsSpacing.md,
                DsSpacing.md,
              ),
              child: _AdminHeader(extended: extended),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
                itemCount: destinations.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DsSpacing.xxs),
                itemBuilder: (context, index) {
                  final item = destinations[index];
                  return _AdminNavTile(
                    item: item,
                    selected: selectedPath == item.path,
                    extended: extended,
                    onTap: () {
                      if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                        Navigator.of(context).maybePop();
                      }
                      context.go(item.path);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DsSpacing.md),
              child: _AdminNavTile(
                item: _AdminNavItem(
                  path: RoutePaths.securitySettings,
                  icon: Icons.lock_outline_rounded,
                  selectedIcon: Icons.lock_rounded,
                  label: 'Security',
                ),
                selected: false,
                extended: extended,
                onTap: () => context.go(RoutePaths.securitySettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final mark = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: DsRadius.borderMd,
      ),
      child: Icon(Icons.admin_panel_settings_rounded, color: colors.primary),
    );

    if (!extended) return mark;

    return Row(
      children: [
        mark,
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: Text(
            l10n.adminPanel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.semiBold,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  const _AdminNavTile({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final _AdminNavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 22,
      color: selected ? colors.primary : colors.onSurfaceVariant,
    );
    final content = AnimatedContainer(
      duration: DsMotion.fast,
      curve: DsCurves.emphasized,
      height: 48,
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: DsRadius.borderMd,
      ),
      child: extended
          ? Row(
              children: [
                const SizedBox(width: DsSpacing.sm),
                icon,
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DsTypography.labelLarge,
                      fontWeight: selected
                          ? DsTypography.semiBold
                          : DsTypography.medium,
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: DsSpacing.xs),
              ],
            )
          : Center(child: icon),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DsRadius.borderMd,
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
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

  factory _AdminNavItem.fromRoleNavigation(RoleNavigationItem item) {
    return _AdminNavItem(
      path: item.path,
      icon: item.icon,
      selectedIcon: item.selectedIcon,
      label: item.label,
    );
  }
}
