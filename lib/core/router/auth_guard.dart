import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/presentation/providers/auth_state.dart';

/// Routes reachable without authentication (public browsing + auth flow).
const _publicRoutes = <String>{
  RoutePaths.splash,
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.register,
  RoutePaths.forgotPassword,
  RoutePaths.otpVerification,
};

const _guestRoutes = <String>{
  RoutePaths.home,
  RoutePaths.search,
  RoutePaths.categories,
  RoutePaths.productDetails,
  RoutePaths.collection,
  RoutePaths.favorites,
  RoutePaths.settings,
};

/// Redirect logic for persistent login + role-based authorization.
///
/// - Unauthenticated users are sent to login for any non-public route.
/// - Authenticated users are bounced away from the auth screens.
/// - Admin routes (`/admin*`) require the ADMIN role; others are sent home.
String? authGuard(BuildContext context, GoRouterState state, AuthState auth) {
  // Wait until the session has been restored before making any decision.
  if (!auth.isInitialized) return null;

  final location = state.matchedLocation;
  final isPublic = _publicRoutes.contains(location);
  final isAuthenticated = auth.isAuthenticated;
  final isGuestAllowed =
      auth.canBrowseAsGuest && _guestRoutes.contains(location);

  if (!isAuthenticated && !isPublic && !isGuestAllowed) {
    return RoutePaths.login;
  }

  if (isAuthenticated &&
      (location == RoutePaths.login ||
          location == RoutePaths.register ||
          location == RoutePaths.forgotPassword)) {
    return AppRoleExperience.forUserRole(auth.user?.role).defaultPath;
  }

  final role = auth.user?.role;
  final experience = AppRoleExperience.forUserRole(role);

  if (isAuthenticated &&
      (location == RoutePaths.home || location == RoutePaths.profile) &&
      experience.defaultPath != RoutePaths.home) {
    return location == RoutePaths.profile
        ? experience.profilePath
        : experience.defaultPath;
  }

  final isAdminRoute = location.startsWith(RoutePaths.admin);
  if (isAdminRoute &&
      role != UserRole.admin &&
      role != UserRole.superAdmin &&
      role != UserRole.support) {
    return RoutePaths.home;
  }

  // Seller storefront routes are sellers/admins only.
  final isSellerRoute = location.startsWith('/seller');
  if (isSellerRoute &&
      role != UserRole.seller &&
      role != UserRole.admin &&
      role != UserRole.superAdmin) {
    return RoutePaths.home;
  }

  return null;
}
