import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/providers/cart_providers.dart';
import '../../features/experience/presentation/providers/role_experience_provider.dart';
import '../design_system/design_system.dart';
import '../experience/role_experience.dart';
import '../localization/l10n_extension.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(BuildContext context, RoleNavigationItem item) {
    final branchIndex = _branchIndexForPath(item.path);
    if (branchIndex == null) {
      context.go(item.path);
      return;
    }
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(roleExperienceProvider);
    final path = GoRouterState.of(context).uri.path;
    final destinations = experience.visibleNavigation.toList(growable: false);
    final selectedIndex = _selectedIndex(destinations, path);
    final actions = experience.visibleQuickActions.toList(growable: false);
    final action = actions.isEmpty ? null : actions.first;

    return switch (experience.role) {
      ExperienceRole.seller => _SellerProductShell(
          navigationShell: navigationShell,
          destinations: destinations,
          selectedIndex: selectedIndex,
          quickAction: action,
          onSelected: (index) => _go(context, destinations[index]),
          onQuickAction: action == null ? null : () => context.go(action.path),
        ),
      ExperienceRole.admin => _AdminFallbackShell(
          navigationShell: navigationShell,
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: (index) => _go(context, destinations[index]),
        ),
      ExperienceRole.buyer => _CustomerProductShell(
          navigationShell: navigationShell,
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: (index) => _go(context, destinations[index]),
        ),
    };
  }

  int _selectedIndex(List<RoleNavigationItem> destinations, String path) {
    final index = destinations.indexWhere(
      (item) => path == item.path || path.startsWith('${item.path}/'),
    );
    return index < 0 ? 0 : index;
  }

  int? _branchIndexForPath(String path) => switch (path) {
        '/home' => 0,
        '/search' => 1,
        '/cart' => 2,
        '/activity' => 3,
        '/profile' => 4,
        '/seller/dashboard' => 5,
        '/seller/products' => 6,
        '/orders' => 7,
        '/seller/customers' => 8,
        '/seller/marketing' => 9,
        '/seller/analytics' => 10,
        '/seller/store' => 11,
        _ => null,
      };
}

class _CustomerProductShell extends StatelessWidget {
  const _CustomerProductShell({
    required this.navigationShell,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final StatefulNavigationShell navigationShell;
  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: context.dsColors.background,
      body: Stack(
        children: [
          const CustomerBackdrop(),
          navigationShell,
        ],
      ),
      // No docked action: the buyer's only quick action is Search, which is
      // already a tab. A floating button duplicating a tab and half-covering
      // the bar was the single ugliest thing on the screen.
      bottomNavigationBar: _CustomerNavigationBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      ),
    );
  }
}

/// The buyer's bottom bar: a floating glass rail.
///
/// Rebuilt to read from the theme rather than a fixed white — it used to stay
/// milk-white in dark mode, floating over aubergine like a leftover from
/// another app. The selected tab now lights a rose gradient tile behind its
/// icon with a soft glow, and the cart carries a live count.
class _CustomerNavigationBar extends ConsumerWidget {
  const _CustomerNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final cartCount = ref.watch(cartCountProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.md,
        0,
        DsSpacing.md,
        DsSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxxl,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.heavy, sigmaY: DsBlur.heavy),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.xs,
              vertical: DsSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: c.surfaceElevated.withValues(alpha: 0.86),
              borderRadius: DsRadius.borderXxxl,
              border: Border.all(color: c.border.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                for (final entry in destinations.asMap().entries)
                  Expanded(
                    child: _CustomerNavItem(
                      item: entry.value,
                      selected: entry.key == selectedIndex,
                      badgeCount: entry.value.surface == ExperienceSurface.cart
                          ? cartCount
                          : 0,
                      onTap: () => onSelected(entry.key),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerNavItem extends StatelessWidget {
  const _CustomerNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final RoleNavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Tooltip(
      message: item.label,
      child: InkResponse(
        radius: 34,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: DsMotion.normal,
                  curve: DsMotion.silk,
                  width: 44,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected ? context.primaryGradient : null,
                    borderRadius: DsRadius.borderPill,
                    boxShadow: selected
                        ? context.glowShadow(c.primary, blur: 14, alpha: 0.34)
                        : null,
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected ? c.onPrimary : c.onSurfaceVariant,
                    size: 21,
                  ),
                ),
                if (badgeCount > 0)
                  PositionedDirectional(
                    top: -3,
                    end: -1,
                    child: _CountDot(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? c.primary : c.onSurfaceVariant,
                  fontSize: DsTypography.labelSmall,
                  fontWeight:
                      selected ? DsTypography.bold : DsTypography.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live cart tally on the bag tab.
class _CountDot extends StatelessWidget {
  const _CountDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: c.surfaceElevated, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: c.onPrimary,
          fontSize: 9,
          fontWeight: DsTypography.bold,
          height: 1,
        ),
      ),
    );
  }
}

class _SellerProductShell extends StatelessWidget {
  const _SellerProductShell({
    required this.navigationShell,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.quickAction,
    this.onQuickAction,
  });

  final StatefulNavigationShell navigationShell;
  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final RoleAction? quickAction;
  final VoidCallback? onQuickAction;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    final palette = context.atelier;
    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: wide && quickAction != null
          ? FloatingActionButton.extended(
              tooltip: quickAction!.label,
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              icon: Icon(quickAction!.icon),
              label: Text(quickAction!.label),
              onPressed: onQuickAction,
            )
          : null,
      body: Stack(
        children: [
          const SellerAtelierBackground(),
          if (wide)
            Row(
              children: [
                _SellerSideNavigation(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                ),
                Expanded(child: navigationShell),
              ],
            )
          else
            navigationShell,
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : _SellerMobileNavigation(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
    );
  }
}

class _SellerSideNavigation extends StatelessWidget {
  const _SellerSideNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: palette.raised,
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SellerBrand(),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: DsRadius.borderMd,
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: palette.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.search,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: DsTypography.labelMedium,
                          fontWeight: DsTypography.medium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: destinations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) => _SellerNavTile(
                    item: destinations[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
              ),
              SellerStatusPill(
                label: context.l10n.sellerLiveStore,
                icon: Icons.check_circle_rounded,
                color: palette.positive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerBrand extends StatelessWidget {
  const _SellerBrand();

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: palette.headerGradient,
            borderRadius: DsRadius.borderMd,
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.ink,
                  fontFamily: DsTypography.fontFamilyDisplay,
                  fontFamilyFallback: DsTypography.displayFallback,
                  fontWeight: DsTypography.bold,
                  fontSize: DsTypography.titleSmall,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.sellerCommandCentre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: DsTypography.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SellerNavTile extends StatelessWidget {
  const _SellerNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final RoleNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DsRadius.borderMd,
          onTap: onTap,
          child: AnimatedContainer(
            duration: DsMotion.fast,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? palette.primarySoft : Colors.transparent,
              borderRadius: DsRadius.borderMd,
              border: Border.all(
                color: selected
                    ? palette.primary.withValues(alpha: 0.24)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: selected ? palette.primary : palette.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? palette.primary : palette.ink,
                      fontWeight:
                          selected ? DsTypography.bold : DsTypography.medium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerMobileNavigation extends StatelessWidget {
  const _SellerMobileNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Container(
      height: 78 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.fromLTRB(
        10,
        8,
        10,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: palette.raised,
        border: Border(top: BorderSide(color: palette.line)),
        boxShadow: palette.shadow,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: destinations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = destinations[index];
          final selected = index == selectedIndex;
          return SizedBox(
            width: 92,
            child: _SellerNavTile(
              item: item,
              selected: selected,
              onTap: () => onSelected(index),
            ),
          );
        },
      ),
    );
  }
}

class _AdminFallbackShell extends StatelessWidget {
  const _AdminFallbackShell({
    required this.navigationShell,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final StatefulNavigationShell navigationShell;
  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminExperience.background,
      body: Stack(
        children: [
          const AdminChromeBackground(),
          Row(
            children: [
              Container(
                width: 88,
                color: AdminExperience.nav,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      for (final entry in destinations.asMap().entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: IconButton(
                            tooltip: entry.value.label,
                            onPressed: () => onSelected(entry.key),
                            icon: Icon(
                              entry.key == selectedIndex
                                  ? entry.value.selectedIcon
                                  : entry.value.icon,
                              color: entry.key == selectedIndex
                                  ? Colors.white
                                  : AdminExperience.navMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: navigationShell),
            ],
          ),
        ],
      ),
    );
  }
}
