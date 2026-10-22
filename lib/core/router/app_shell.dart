import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/experience_labels.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/open_route.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/router/tab_reselect.dart';
import 'package:reem/core/sync/outbox_providers.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/features/social/presentation/widgets/create_sheet.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(BuildContext context, WidgetRef ref, RoleNavigationItem item) {
    final branchIndex = _branchIndexForPath(item.path);
    if (branchIndex == null) {
      context.go(item.path);
      return;
    }
    final reselected = branchIndex == navigationShell.currentIndex;
    navigationShell.goBranch(branchIndex, initialLocation: reselected);
    // `goBranch` pops the branch to its root, which is the right half of the
    // answer. The other half — scrolling the page she is on back to the top —
    // only the page can do, so the tap is announced and Home listens.
    if (reselected) {
      ref.read(tabReselectProvider(branchIndex).notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Holds the drain alive for the life of the shell. Nothing else watches
    // it, and a queue that only drains when a screen happens to ask would sit
    // full for exactly as long as she is not looking at the right screen.
    ref.watch(outboxDrainProvider);

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
        onSelected: (index) => _go(context, ref, destinations[index]),
        // Pushed, not replaced: «منتج جديد» is a place she comes back from,
        // and `go` left its back arrow with nothing under it.
        onQuickAction: action == null
            ? null
            : () => openRoute(context, action.path),
      ),
      ExperienceRole.admin => _AdminFallbackShell(
        navigationShell: navigationShell,
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: (index) => _go(context, ref, destinations[index]),
      ),
      ExperienceRole.buyer => _CustomerProductShell(
        navigationShell: navigationShell,
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: (index) => _go(context, ref, destinations[index]),
      ),
    };
  }

  int _selectedIndex(List<RoleNavigationItem> destinations, String path) {
    final index = destinations.indexWhere(
      (item) => path == item.path || path.startsWith('${item.path}/'),
    );
    return index < 0 ? 0 : index;
  }

  /// Which stack in the shell a destination lives in.
  ///
  /// It mirrors the branch order in the router by hand, so the two must be
  /// edited together — and were not, the last time the seller's tabs changed.
  /// A path with no branch is pushed instead, which is the right answer for
  /// every screen that is a destination but not a tab.
  int? _branchIndexForPath(String path) => switch (path) {
    RoutePaths.home => 0,
    RoutePaths.search => 1,
    RoutePaths.closet => 2,
    RoutePaths.profile => 3,
    RoutePaths.sellerDashboard => 4,
    RoutePaths.myProducts => 5,
    RoutePaths.sellerOrders => 6,
    RoutePaths.sellerAnalytics => 7,
    RoutePaths.sellerStore => 8,
    _ => null,
  };
}

class _CustomerProductShell extends StatefulWidget {
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
  State<_CustomerProductShell> createState() => _CustomerProductShellState();
}

class _CustomerProductShellState extends State<_CustomerProductShell> {
  /// The rail's real height, measured. Starts at the token so the first frame
  /// is already roughly right, and settles on the truth one frame later —
  /// which matters because the bar grows with the system text size.
  final _barHeight = ValueNotifier<double>(
    DsSizes.bottomBarHeight + DsSpacing.sm,
  );

  @override
  void dispose() {
    _barHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: context.dsColors.background,
      body: Stack(
        children: [
          const CustomerBackdrop(),
          // The page is drawn under the glass rail on purpose; this is what
          // stops its *content* ending up under it. See [BottomBarInset].
          ValueListenableBuilder<double>(
            valueListenable: _barHeight,
            builder: (context, height, child) =>
                BottomBarInset(height: height, child: child!),
            child: widget.navigationShell,
          ),
        ],
      ),
      // No docked action: the buyer's only quick action is Search, which is
      // already a tab. A floating button duplicating a tab and half-covering
      // the bar was the single ugliest thing on the screen.
      bottomNavigationBar: MeasuredHeight(
        onHeight: (height) => _barHeight.value = height,
        child: _CustomerNavigationBar(
          destinations: widget.destinations,
          selectedIndex: widget.selectedIndex,
          onSelected: widget.onSelected,
        ),
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
    // The badge belongs to whichever tab *is* the cart, and since Rooms took
    // that slot no buyer tab is. Watching regardless would rebuild the whole
    // bar on every basket change to render nothing.
    final showsCart = destinations.any(
      (item) => item.surface == ExperienceSurface.cart,
    );
    final cartCount = showsCart ? ref.watch(cartCountProvider) : 0;

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
            // A floor, not a height. The rail used to be pinned at 68 while
            // the label inside it grew with the system text setting, so at
            // anything past ~130% the caption was clipped and then the whole
            // column overflowed. Letting the bar grow costs a few pixels of
            // page and keeps every tab readable.
            constraints: const BoxConstraints(minHeight: 68),
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
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                for (final entry in destinations.asMap().entries) ...[
                  // Publishing sits in the middle of the bar, between the
                  // halves of the tabs. It used to be an icon in the home
                  // header — the one action that makes this a social app,
                  // reachable from one screen and noticed on none.
                  if (entry.key == destinations.length ~/ 2)
                    const _CreateButton(),
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

    final label = item.labelOf(context.l10n);

    // One node for the whole tab, announced as a selected/unselected tab
    // rather than as an icon and a caption read out separately. `container`
    // is what collapses the two children into it. The badge is drawn at a
    // fixed size so it cannot swallow the icon at 160% text, so its number is
    // carried here instead — otherwise a screen reader would never hear it.
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: badgeCount > 0 ? '$label ($badgeCount)' : label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
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
                            ? context.glowShadow(
                                c.primary,
                                blur: 14,
                                alpha: 0.34,
                              )
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
                DsGaps.vXxs,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: context.dsText.caption
                        .tint(selected ? c.primary : c.onSurfaceVariant)
                        .copyWith(
                          fontWeight: selected
                              ? DsTypography.bold
                              : DsTypography.medium,
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

/// The rose disc in the middle of the buyer's bar: post, reel or story.
///
/// Not a tab — it opens the create sheet over whatever she is looking at and
/// never changes which tab is selected, so it carries no selected state.
class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final label = context.l10n.createTooltip;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
      child: Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: Tooltip(
            message: label,
            child: InkResponse(
              radius: 30,
              onTap: () => showCreateSheet(context),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: context.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: context.glowShadow(c.primary, blur: 16, alpha: 0.4),
                ),
                child: Icon(Icons.add_rounded, color: c.onPrimary, size: 28),
              ),
            ),
          ),
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
    // The tally is furniture, not prose: it stays a 17dp dot at every system
    // text size rather than swelling over the icon it is pinned to. The count
    // still reaches a screen reader — the tab's own semantic label carries it.
    return MediaQuery.withNoTextScaling(
      child: Container(
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: DsRadius.borderPill,
          border: Border.all(color: c.surfaceElevated, width: 1.5),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: context.dsText.micro.bold
              .tint(c.onPrimary)
              .copyWith(height: 1),
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
              tooltip: quickAction!.labelOf(context.l10n),
              backgroundColor: palette.primary,
              foregroundColor: DsColors.onMedia,
              icon: Icon(quickAction!.icon),
              label: Text(quickAction!.labelOf(context.l10n)),
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
            // The seller's bar is opaque and does not extend the body under
            // itself, so the page already clears it — but the system inset is
            // spent inside the bar, and a page still adding its own put a
            // gesture bar's worth of blank under every screen.
            MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: navigationShell,
            ),
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
          padding: const EdgeInsets.all(DsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SellerBrand(),
              DsGaps.vXl,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm,
                  vertical: DsSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: DsRadius.borderMd,
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: palette.muted),
                    DsGaps.hXs,
                    Expanded(
                      child: Text(
                        context.l10n.search,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.labelMedium.tint(palette.muted),
                      ),
                    ),
                  ],
                ),
              ),
              DsGaps.vLg,
              Expanded(
                child: ListView.separated(
                  itemCount: destinations.length,
                  separatorBuilder: (_, _) => DsGaps.vXxs,
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
          child: const Icon(Icons.storefront_rounded, color: DsColors.onMedia),
        ),
        DsGaps.hSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.tileTitle.displayFamily.bold.tint(
                  palette.ink,
                ),
              ),
              DsGaps.vXxxs,
              Text(
                l10n.sellerCommandCentre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.caption.tint(palette.muted),
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
    final label = item.labelOf(context.l10n);
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DsRadius.borderMd,
          onTap: onTap,
          child: AnimatedContainer(
            duration: DsMotion.fast,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
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
                DsGaps.hSm,
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body
                        .tint(selected ? palette.primary : palette.ink)
                        .copyWith(
                          fontWeight: selected
                              ? DsTypography.bold
                              : DsTypography.medium,
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
      // Every destination on screen at once, each an equal share of the
      // width, icon over label. The old strip scrolled sideways in fixed
      // 92-pixel tiles with the label beside the icon: on a phone the labels
      // were cut to «لو…» / «المن…» and the fifth tab lived off screen.
      child: Row(
        children: [
          for (var index = 0; index < destinations.length; index++)
            Expanded(
              child: _SellerMobileNavItem(
                item: destinations[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _SellerMobileNavItem extends StatelessWidget {
  const _SellerMobileNavItem({
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
    final label = item.labelOf(context.l10n);
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkResponse(
          radius: 32,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: DsMotion.fast,
                width: 44,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? palette.primarySoft : Colors.transparent,
                  borderRadius: DsRadius.borderPill,
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: selected ? palette.primary : palette.muted,
                ),
              ),
              DsGaps.vXxs,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: context.dsText.caption
                      .tint(selected ? palette.primary : palette.muted)
                      .copyWith(
                        fontWeight: selected
                            ? DsTypography.bold
                            : DsTypography.medium,
                      ),
                ),
              ),
            ],
          ),
        ),
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
      backgroundColor: context.console.background,
      body: Stack(
        children: [
          const AdminChromeBackground(),
          Row(
            children: [
              Container(
                // The console is a landscape-tablet surface, but staff open it
                // on whatever is in their pocket. 88dp of a 360dp phone is a
                // quarter of the width, so the rail narrows on a small screen
                // rather than squeezing the page it exists to navigate.
                width: MediaQuery.sizeOf(context).width < DsBreakpoints.medium
                    ? 64
                    : 88,
                color: context.console.nav,
                child: SafeArea(
                  right: false,
                  child: Column(
                    children: [
                      DsGaps.vMd,
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: DsColors.onMedia,
                      ),
                      DsGaps.vLg,
                      // Scrollable. The console gained sections faster than
                      // the rail gained room: eight destinations on a short
                      // handset ran the fixed column straight off the bottom
                      // of the screen, and the last two could not be reached
                      // at all.
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            for (final entry in destinations.asMap().entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: DsSpacing.xxs,
                                ),
                                child: IconButton(
                                  tooltip: entry.value.labelOf(context.l10n),
                                  isSelected: entry.key == selectedIndex,
                                  onPressed: () => onSelected(entry.key),
                                  icon: Icon(
                                    entry.key == selectedIndex
                                        ? entry.value.selectedIcon
                                        : entry.value.icon,
                                    color: entry.key == selectedIndex
                                        ? DsColors.onMedia
                                        : context.console.navMuted,
                                  ),
                                ),
                              ),
                          ],
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
