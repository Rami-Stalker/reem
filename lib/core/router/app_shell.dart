import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/design_system.dart';
import 'route_names.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = context.isDarkMode;
    return Scaffold(
      extendBody: true,
      backgroundColor: colors.background,
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 58,
        width: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: context.storyRingGradient,
          boxShadow: context.luxuryShadow,
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () => context.pushNamed(RouteNames.adminAnalytics),
          child: Icon(Icons.add_rounded, size: 30, color: colors.onPrimary),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: DsRadius.borderXxxl,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: DsBlur.medium, sigmaY: DsBlur.medium),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surface.withValues(alpha: 0.92)
                    : colors.surface.withValues(alpha: 0.9),
                borderRadius: DsRadius.borderXxxl,
                border: Border.all(color: colors.glassBorder),
                boxShadow: context.softShadow,
              ),
              child: NavigationBar(
                height: 68,
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: colors.primary.withValues(alpha: 0.18),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onTap,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined, color: colors.onSurfaceVariant),
                    selectedIcon: Icon(Icons.home_rounded, color: colors.primary),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_outline, color: colors.onSurfaceVariant),
                    selectedIcon: Icon(Icons.favorite_rounded, color: colors.primary),
                    label: 'Wishlist',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined, color: colors.onSurfaceVariant),
                    selectedIcon: Icon(Icons.settings_rounded, color: colors.primary),
                    label: 'Settings',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline, color: colors.onSurfaceVariant),
                    selectedIcon: Icon(Icons.person_rounded, color: colors.primary),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
