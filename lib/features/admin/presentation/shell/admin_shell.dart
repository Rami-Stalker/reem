import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/experience_labels.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_jump_palette.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The frame around every console page: the courtyard's night, down the side.
///
/// The rail is grouped the way the work is — people, the market, trust,
/// money, insight, the house — so nineteen destinations read as six rooms. A
/// destination with a queue behind it carries its count in champagne, the
/// same light as the home's lit doors, so she can see from any page where
/// people are waiting. «إلى أين؟» and Ctrl/⌘ K open the jump palette from
/// anywhere in the console.
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
    // every destination names a permission. Reading that as a denial drew a
    // console with an empty rail: reachable by typing a URL and by nothing
    // else. `authGuard` already treats an empty set as unknown and lets the
    // request through; the two have to agree. The server still answers 403
    // for anything she genuinely may not do.
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

    void openJump() =>
        showAdminJumpPalette(context, adminJumpDestinations(permissions, l10n));

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): openJump,
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): openJump,
    };

    if (width < 720) {
      return CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: palette.background,
            appBar: AppBar(
              backgroundColor: palette.nav,
              foregroundColor: DsColors.onMedia,
              flexibleSpace: const CourtNight(vertical: false),
              title: Text(
                l10n.adminPanel,
                style: context.dsText.cardTitle.displayFamily.bold.tint(
                  DsColors.onMedia,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: l10n.adminCourtJumpShort,
                  onPressed: openJump,
                  icon: const Icon(Icons.travel_explore_rounded),
                ),
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
                onJump: openJump,
              ),
            ),
            body: Stack(children: [const AdminChromeBackground(), child]),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                    onJump: openJump,
                  ),
                  Expanded(child: child),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rooms of the house, in the order the rail lists them.
enum _NavGroup { people, market, trust, money, insight, house }

_NavGroup? _groupOf(String path) => switch (path) {
  RoutePaths.adminUsers ||
  RoutePaths.adminAccountVerifications ||
  RoutePaths.adminSellerApplications ||
  RoutePaths.adminSellers => _NavGroup.people,
  RoutePaths.adminProducts ||
  RoutePaths.adminOrders ||
  RoutePaths.adminDelivery => _NavGroup.market,
  RoutePaths.adminSupport ||
  RoutePaths.adminModeration ||
  RoutePaths.adminContent ||
  RoutePaths.adminReports => _NavGroup.trust,
  RoutePaths.adminFinancials || RoutePaths.adminCommissions => _NavGroup.money,
  RoutePaths.adminAnalytics ||
  RoutePaths.adminTrends ||
  RoutePaths.adminValue => _NavGroup.insight,
  RoutePaths.adminAuditLogs ||
  RoutePaths.adminPolicies ||
  RoutePaths.adminSystemSettings => _NavGroup.house,
  _ => null,
};

String _groupLabel(AppLocalizations l10n, _NavGroup group) => switch (group) {
  _NavGroup.people => l10n.adminCourtGroupPeople,
  _NavGroup.market => l10n.adminCourtGroupMarket,
  _NavGroup.trust => l10n.adminCourtGroupTrust,
  _NavGroup.money => l10n.adminCourtGroupMoney,
  _NavGroup.insight => l10n.adminCourtGroupInsight,
  _NavGroup.house => l10n.adminCourtGroupHouse,
};

/// The queue whose backlog a destination carries as a count.
String? _queueOf(String path) => switch (path) {
  RoutePaths.adminSellerApplications => 'sellerApplications',
  RoutePaths.adminAccountVerifications => 'accountVerifications',
  RoutePaths.adminModeration => 'moderation',
  RoutePaths.adminSupport => 'support',
  RoutePaths.adminReports => 'reports',
  _ => null,
};

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.destinations,
    required this.selectedPath,
    required this.extended,
    required this.onJump,
  });

  final List<_AdminNavItem> destinations;
  final String selectedPath;
  final bool extended;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Destinations with their group headings interleaved, in rail order.
    final entries = <Widget>[];
    _NavGroup? current;
    for (final item in destinations) {
      final group = _groupOf(item.path);
      if (group != null && group != current) {
        entries.add(
          extended
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    DsSpacing.sm,
                    DsSpacing.lg,
                    DsSpacing.sm,
                    DsSpacing.xs,
                  ),
                  child: Text(
                    _groupLabel(l10n, group),
                    style: context.dsText.overline.tint(
                      DsColors.gold200.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DsSpacing.sm,
                    horizontal: DsSpacing.lg,
                  ),
                  child: Divider(
                    height: DsSizes.dividerThickness,
                    color: DsColors.onMediaFaint,
                  ),
                ),
        );
        current = group;
      }
      entries.add(
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
          child: _AdminNavTile(
            item: item,
            selected: selectedPath == item.path,
            extended: extended,
            onTap: () {
              if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                Navigator.of(context).maybePop();
              }
              context.go(item.path);
            },
          ),
        ),
      );
    }

    return SizedBox(
      width: extended ? 272 : 88,
      child: CourtNight(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
                child: _JumpButton(extended: extended, onTap: onJump),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpacing.sm,
                    DsSpacing.xs,
                    DsSpacing.sm,
                    DsSpacing.md,
                  ),
                  children: entries,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DsSpacing.sm),
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
    const mark = CourtArchMedallion(
      icon: Icons.admin_panel_settings_rounded,
      lit: true,
    );

    if (!extended) return mark;

    return Row(
      children: [
        mark,
        DsGaps.hSm,
        Expanded(
          child: Text(
            l10n.adminPanel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.cardTitle.displayFamily.bold.tint(
              DsColors.onMedia,
            ),
          ),
        ),
      ],
    );
  }
}

/// «إلى أين؟» at the top of the rail: the jump palette, one tap away.
class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.extended, required this.onTap});

  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = extended
        ? Row(
            children: [
              const Icon(
                Icons.travel_explore_rounded,
                size: DsSizes.iconSm,
                color: DsColors.gold200,
              ),
              DsGaps.hSm,
              Expanded(
                child: Text(
                  l10n.adminCourtJumpShort,
                  style: context.dsText.labelLarge.tint(DsColors.onMediaMuted),
                ),
              ),
              // l10n-ignore: a key cap names the keys printed on the keyboard
              const CourtKeyCap(label: 'Ctrl K'),
            ],
          )
        : const Center(
            child: Icon(
              Icons.travel_explore_rounded,
              size: DsSizes.iconSm,
              color: DsColors.gold200,
            ),
          );

    return Tooltip(
      message: l10n.adminCourtJumpShort,
      child: Semantics(
        button: true,
        label: l10n.adminCourtJumpShort,
        excludeSemantics: true,
        child: Material(
          color: DsColors.onMedia.withValues(alpha: 0.07),
          shape: const StadiumBorder(
            side: BorderSide(color: DsColors.onMediaFaint),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: DsSizes.controlMd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final queue = _queueOf(item.path);
    final waiting = queue == null
        ? null
        : ref.watch(adminQueueDepthProvider(queue)).value;
    final hasQueue = waiting != null && waiting > 0;

    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: DsSizes.iconSm + DsSpacing.xxxs,
      color: selected ? DsColors.gold100 : palette.navMuted,
    );

    final count = hasQueue
        ? Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.xs,
              vertical: DsSpacing.xxxs,
            ),
            decoration: BoxDecoration(
              color: DsColors.gold300.withValues(alpha: 0.18),
              borderRadius: DsRadius.borderPill,
              border: Border.all(
                color: DsColors.gold300.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              formatCount(waiting),
              style: context.dsText.badge.tint(DsColors.gold100),
            ),
          )
        : null;

    final content = AnimatedContainer(
      duration: DsReducedMotion.duration(DsMotion.fast),
      curve: DsCurves.emphasized,
      height: DsSizes.controlMd,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: AlignmentDirectional.centerStart.resolve(
                  Directionality.of(context),
                ),
                end: AlignmentDirectional.centerEnd.resolve(
                  Directionality.of(context),
                ),
                colors: [
                  DsColors.gold300.withValues(alpha: 0.22),
                  DsColors.mauve600.withValues(alpha: 0.18),
                ],
              )
            : null,
        borderRadius: DsRadius.borderPill,
        border: selected
            ? Border.all(color: DsColors.gold300.withValues(alpha: 0.35))
            : null,
      ),
      child: extended
          ? Row(
              children: [
                DsGaps.hSm,
                icon,
                DsGaps.hSm,
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
                if (count != null) ...[DsGaps.hXs, count],
                DsGaps.hSm,
              ],
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: icon),
                // Collapsed, a waiting queue is a lamp beside the icon.
                if (hasQueue)
                  PositionedDirectional(
                    top: DsSpacing.xs,
                    end: DsSpacing.sm,
                    child: Container(
                      width: DsSpacing.xs,
                      height: DsSpacing.xs,
                      decoration: BoxDecoration(
                        color: DsColors.gold200,
                        shape: BoxShape.circle,
                        boxShadow: context.glowShadow(
                          DsColors.gold300,
                          blur: 8,
                          alpha: 0.9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );

    final label = hasQueue
        ? '${item.label}، ${formatCount(waiting)}'
        : item.label;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DsRadius.borderPill,
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
  /// customer's bottom bar and the seller's rail read, so a console rail and a
  /// nav bar cannot call the same screen two different things.
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
