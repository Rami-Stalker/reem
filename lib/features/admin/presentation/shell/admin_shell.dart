import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/experience_labels.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/l10n/app_localizations.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final l10n = context.l10n;
    final path = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final permissions = ref.watch(currentPermissionsProvider);
    // The console draws only the doors this operator can walk through. The
    // server decides again on every request; this is about not offering a
    // finance screen to a support agent and calling the 403 a feature.
    //
    // An empty set is "we were not told", not "she may do nothing" — the user
    // model defaults `permissions` to `{}` when the payload omits the key, and
    // every one of the sixteen destinations names a permission. Reading that
    // as a denial drew a console with an empty rail: reachable by typing a URL
    // and by nothing else. `authGuard` already treats an empty set as unknown
    // and lets the request through; the two have to agree, and this is the
    // side that was wrong. The server still answers 403 for anything she
    // genuinely may not do.
    final unknownPermissions = permissions.isEmpty;
    final destinations = AppRoleExperience.admin.navigation
        .where(
          (item) =>
              item.permission == null ||
              unknownPermissions ||
              permissions.contains(item.permission),
        )
        .map((item) => _AdminNavItem.fromRoleNavigation(item, l10n))
        .toList(growable: false);

    if (width < 720) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.nav,
          foregroundColor: DsColors.onMedia,
          title: Text(l10n.adminPanel),
          actions: [
            IconButton(
              tooltip: l10n.adminSettings,
              onPressed: () => context.push(RoutePaths.adminSystemSettings),
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
      backgroundColor: palette.background,
      body: Stack(
        children: [
          const AdminChromeBackground(),
          Row(
            children: [
              _AdminNavigation(
                destinations: destinations,
                selectedPath: path,
                extended: width >= 1100,
              ),
              VerticalDivider(width: 1, color: palette.line),
              Expanded(child: child),
            ],
          ),
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
    final l10n = context.l10n;
    final palette = context.console;
    return Container(
      width: extended ? 260 : 88,
      color: palette.nav,
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
                  label: l10n.adminSecurity,
                ),
                selected: false,
                extended: extended,
                onTap: () => context.push(RoutePaths.securitySettings),
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
    final mark = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: DsColors.onMedia.withValues(alpha: .08),
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: DsColors.onMedia.withValues(alpha: .1)),
      ),
      child: const Icon(
        Icons.admin_panel_settings_rounded,
        color: DsColors.onMedia,
      ),
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
            style: context.dsText.tileTitle.semibold.tint(DsColors.onMedia),
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
    final palette = context.console;
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 22,
      color: selected ? DsColors.onMedia : palette.navMuted,
    );
    final content = AnimatedContainer(
      duration: DsMotion.fast,
      curve: DsCurves.emphasized,
      height: 48,
      decoration: BoxDecoration(
        color: selected
            ? palette.primary.withValues(alpha: 0.28)
            : Colors.transparent,
        borderRadius: DsRadius.borderSm,
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
                    style: context.dsText.labelLarge
                        .tint(selected ? DsColors.onMedia : palette.navMuted)
                        .copyWith(
                          fontWeight: selected
                              ? DsTypography.semiBold
                              : DsTypography.medium,
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
            borderRadius: DsRadius.borderSm,
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

  /// The label is resolved at display time rather than stored on
  /// [RoleNavigationItem]: that declaration is a `const` shared by every
  /// locale, so its `label` is an English identifier for the destination.
  ///
  /// The mapping itself lives in `RoleNavigationItemLabel`, beside the one the
  /// customer's bottom bar and the seller's rail read. It used to be a private
  /// copy here, which is how a console rail and a nav bar end up calling the
  /// same screen two different things.
  factory _AdminNavItem.fromRoleNavigation(
    RoleNavigationItem item,
    AppLocalizations l10n,
  ) {
    return _AdminNavItem(
      path: item.path,
      icon: item.icon,
      selectedIcon: item.selectedIcon,
      label: item.labelOf(l10n),
    );
  }
}
