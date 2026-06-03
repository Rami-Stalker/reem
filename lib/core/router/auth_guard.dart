import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

// bool isLoggedIn = false;

final _publicRoutes = {
  RoutePaths.splash,
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.register,
  RoutePaths.forgotPassword,
};

String? authGuard(BuildContext context, GoRouterState state, Ref ref) {
  final auth = ref.watch(authNotifierProvider);

  if (!auth.isInitialized) return null;

  final location = state.matchedLocation;
  final isPublic = _publicRoutes.contains(location);
  final isAuthenticated = auth.isAuthenticated;

  if (!isAuthenticated && !isPublic) return RoutePaths.login;
  if (isAuthenticated &&
      (location == RoutePaths.login ||
          location == RoutePaths.register ||
          location == RoutePaths.forgotPassword)) {
    return RoutePaths.home;
  }
  return null;
}


//   final isGoingToLogin = state.matchedLocation == '/login';

//   if (!isLoggedIn && !isGoingToLogin) {
//     return '/login';
//   }

//   if (isLoggedIn && isGoingToLogin) {
//     return '/';
//   }

//   return null;
// }