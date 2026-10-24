import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/router/route_paths.dart';

/// The paths that are *tabs* rather than places.
///
/// A tab is switched to; everything else is gone into and come back from. The
/// distinction is the whole reason [openRoute] exists: `context.go` on a
/// destination replaces the stack, so the screen it opens has nothing to pop
/// and its back button does nothing at all — which is exactly what happened to
/// «المفضلة» from settings, to every card on the activity surface, and to half
/// the admin console.
const _tabPaths = <String>{
  RoutePaths.home,
  RoutePaths.search,
  RoutePaths.rooms,
  RoutePaths.activity,
  RoutePaths.profile,
  RoutePaths.sellerDashboard,
  RoutePaths.myProducts,
  RoutePaths.sellerOrders,
  RoutePaths.sellerAnalytics,
  RoutePaths.sellerStore,
};

/// True when [path] names one of the bottom bar's own destinations.
bool isTabPath(String path) => _tabPaths.contains(Uri.parse(path).path);

/// Opens [path] the way its kind wants to be opened.
///
/// Tabs are switched to, so the shell survives and the bar stays put.
/// Everything else is pushed, so it has a route underneath it and its back
/// button works.
void openRoute(BuildContext context, String path) {
  if (isTabPath(path)) {
    context.go(path);
    return;
  }
  context.push(path);
}

/// Goes back — and, when there is nowhere back to go, goes home.
///
/// Every back arrow in the app leads here. The fallback is the point: a screen
/// reached by `context.go`, by a notification tap or by a deep link has no
/// route underneath it, so `pop` and `maybePop` both do nothing at all while
/// the arrow stays drawn and tappable. An arrow that is on screen has to lead
/// somewhere, so it leads to the front door, which the guard then routes to
/// the right home for her role.
void popOrHome(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    // No router overhead at all — a widget test, or a visual preview.
    unawaited(Navigator.of(context).maybePop());
    return;
  }
  if (router.canPop()) {
    router.pop();
    return;
  }
  router.go(RoutePaths.home);
}
