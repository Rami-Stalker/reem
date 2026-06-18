import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design_system/design_system.dart';
import '../experience/role_experience.dart';
import '../../features/experience/presentation/providers/role_experience_provider.dart';

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
    final colors = context.dsColors;
    final isDark = context.isDarkMode;
    final experience = ref.watch(roleExperienceProvider);
    final identity = experience.visualIdentity;
    final path = GoRouterState.of(context).uri.path;
    final destinations = experience.visibleNavigation.toList(growable: false);
    final selectedIndex = _selectedIndex(destinations, path);
    final actions = experience.visibleQuickActions.toList(growable: false);
    final action = actions.isEmpty ? null : actions.first;

    return Scaffold(
      extendBody: true,
      backgroundColor: colors.background,
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: action == null
          ? null
          : Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: identity.gradient,
                boxShadow: context.luxuryShadow,
              ),
              child: FloatingActionButton(
                tooltip: action.label,
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: () => context.go(action.path),
                child: Icon(action.icon, size: 28, color: colors.onPrimary),
              ),
            ),
      bottomNavigationBar: _RoleNavigationSurface(
        isDark: isDark,
        identity: identity,
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: (index) => _go(context, destinations[index]),
      ),
    );
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

class _RoleNavigationSurface extends StatelessWidget {
  const _RoleNavigationSurface({
    required this.isDark,
    required this.identity,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool isDark;
  final RoleVisualIdentity identity;
  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxxl,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DsBlur.medium,
            sigmaY: DsBlur.medium,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surface.withValues(alpha: 0.92)
                  : colors.surface.withValues(alpha: 0.9),
              borderRadius: DsRadius.borderXxxl,
              border: Border.all(color: colors.glassBorder),
              boxShadow: context.softShadow,
            ),
            child: destinations.length <= 5
                ? NavigationBar(
                    height: 68,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    indicatorColor: identity.primary.withValues(alpha: 0.16),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    destinations: [
                      for (final item in destinations)
                        NavigationDestination(
                          icon: Icon(item.icon, color: colors.onSurfaceVariant),
                          selectedIcon: Icon(
                            item.selectedIcon,
                            color: identity.primary,
                          ),
                          label: item.label,
                        ),
                    ],
                  )
                : _ScrollableNavigationStrip(
                    identity: identity,
                    destinations: destinations,
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScrollableNavigationStrip extends StatelessWidget {
  const _ScrollableNavigationStrip({
    required this.identity,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final RoleVisualIdentity identity;
  final List<RoleNavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
        itemCount: destinations.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
        itemBuilder: (context, index) {
          final item = destinations[index];
          final selected = index == selectedIndex;
          return Tooltip(
            message: item.label,
            child: InkWell(
              borderRadius: DsRadius.borderFull,
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: DsMotion.fast,
                curve: DsCurves.emphasized,
                width: 96,
                margin: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
                decoration: BoxDecoration(
                  color: selected
                      ? identity.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: DsRadius.borderFull,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 21,
                      color: selected
                          ? identity.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DsTypography.labelSmall,
                        fontWeight: selected
                            ? DsTypography.semiBold
                            : DsTypography.medium,
                        color: selected
                            ? identity.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
