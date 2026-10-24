import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/ds_theme_extension.dart';

NavigationBarThemeData dsNavigationBarTheme(DsThemeExtension ds) {
  return NavigationBarThemeData(
    backgroundColor: ds.colors.surface,
    indicatorColor: ds.colors.primary.withValues(alpha: 0.15),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? ds.colors.primary : ds.colors.onSurfaceVariant,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected ? ds.colors.primary : ds.colors.onSurfaceVariant,
        size: 24,
      );
    }),
  );
}

BottomNavigationBarThemeData dsBottomNavTheme(DsThemeExtension ds) {
  return BottomNavigationBarThemeData(
    backgroundColor: ds.colors.surface,
    selectedItemColor: ds.colors.primary,
    unselectedItemColor: ds.colors.onSurfaceVariant,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  );
}
