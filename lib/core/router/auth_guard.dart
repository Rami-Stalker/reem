import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/experience/role_experience.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';

/// Routes reachable without authentication (public browsing + auth flow).
const _publicRoutes = <String>{
  RoutePaths.splash,
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.signInCode,
  RoutePaths.authRequired,
  RoutePaths.register,
  RoutePaths.forgotPassword,
  RoutePaths.otpVerification,
  // She cannot sign in — that is the entire premise of opening a recovery
  // case, so gating this behind a session would make it unreachable by
  // exactly the people it exists for.
  RoutePaths.accountRecovery,
  RoutePaths.home,
  RoutePaths.search,
  RoutePaths.keywordSearch,
  RoutePaths.cart,
  RoutePaths.activity,
  RoutePaths.profile,
  RoutePaths.categories,
  RoutePaths.category,
  RoutePaths.productDetails,
  RoutePaths.collection,
  RoutePaths.storyViewer,
  RoutePaths.userProfile,
  RoutePaths.favorites,
  RoutePaths.settings,
  RoutePaths.appearance,
  RoutePaths.language,
  // `coupons`, `rewards` and `wallet` are deliberately *not* here. Each one
  // is a balance belonging to one account, so a guest opening it got a 401
  // rendered as an error rather than an invitation to sign in. Off this list
  // the guard sends her to `authRequired` with a `from`, and she lands back
  // on the screen she wanted. `settings`, `appearance` and `language` stay
  // public because they are device preferences, not account data.
  // The published policies, readable without an account. A woman deciding
  // whether to sign up has to be able to read what she would be agreeing to,
  // and the server answers these routes unauthenticated for the same reason.
  RoutePaths.policies,
  RoutePaths.policyDetail,
  // «الصالونات والجمال», the browsing half. A shared salon link has to open
  // for a woman who has not signed in — that is what makes it worth sharing —
  // and the server answers both of these unauthenticated. Booking, «حجوزاتي»
  // and the owner's workspace are deliberately absent: each is about one
  // account, so the guard sends her to `authRequired` with a `from` and she
  // lands back on the salon she was looking at.
  RoutePaths.salons,
  RoutePaths.salon,
  RoutePaths.likeSheet,
  RoutePaths.commentSheet,
  // A guest may browse the community and the reels feed, and that is the whole
  // commerce case: she follows a link into a look, sees the dress and reaches
  // the boutique before she has an account. Publishing and reacting are not
  // here — those need a session, and the guard sends her to `authRequired`
  // with a `from` so she lands back where she was.
  RoutePaths.socialFeed,
  RoutePaths.reels,
  // One piece on its own, and one boutique's whole shelf — the two
  // destinations a shared link most often points at. Both read endpoints the
  // API already answers unauthenticated, and gating them would mean a link
  // forwarded on WhatsApp opens a sign-in wall for the one person it was sent
  // to. Reacting still needs a session; the guard catches that at the gesture.
  RoutePaths.contentDetail,
  RoutePaths.sellerProducts,
  // Q64 — the tracking code *is* the credential, and Q46 P1 lets guests buy.
  // Requiring a login to follow a parcel would strand the very customers the
  // guest checkout exists for, and matches the backend, which marks the same
  // endpoint @Public() for exactly that reason.
  RoutePaths.shipmentTracking,
  // Q46 P1 — a guest may buy, so the till and what comes out of it are hers
  // too. These three were behind the guard while the backend's checkout route
  // demanded a signed-in id, which made the guest cart a dead end: she could
  // fill a basket, tap «إتمام الشراء», and be sent to a sign-in screen. Both
  // halves move together — `OrdersController` now carries
  // `@Authorize({ allowGuest: true })` and scopes every read to her guest
  // session, exactly as the cart already did.
  //
  // Her session token is her only claim on the order afterwards, which is a
  // weaker credential than an account and is the trade Q46 P1 makes. What it
  // is not is *unscoped*: one guest cannot read another's order.
  RoutePaths.checkout,
  RoutePaths.orders,
  RoutePaths.orderDetail,
};

const _sellerToolRoutes = <String>{
  RoutePaths.addPost,
  RoutePaths.addStory,
  RoutePaths.myProducts,
  RoutePaths.productForm,
  RoutePaths.sellerDashboard,
  RoutePaths.sellerAnalytics,
  RoutePaths.sellerTrends,
  RoutePaths.sellerRadar,
  RoutePaths.sellerProductIntelligence,
  RoutePaths.sellerHealth,
  RoutePaths.sellerStore,
  RoutePaths.sellerEarnings,
  RoutePaths.sellerOrders,
  RoutePaths.sellerReturns,
  RoutePaths.sellerReviews,
};

/// Redirect logic for persistent login + role-based authorization.
///
/// - Unauthenticated users may browse public commerce/community routes.
/// - Protected routes show a sign-in explainer instead of forcing login.
/// - Authenticated users are bounced away from the auth screens.
/// - Admin routes (`/admin*`) require the ADMIN role; others are sent home.
String? authGuard(BuildContext context, GoRouterState state, AuthState auth) {
  // Wait until the session has been restored before making any decision.
  if (!auth.isInitialized) return null;

  final location = state.matchedLocation;

  // The *pattern*, not the location. `_publicRoutes` is written in route
  // spellings — `/user/:id`, `/track/:code`, `/category/:category` — and
  // `matchedLocation` is the concrete path, so `contains('/user/abc')` was
  // false for every one of them. Ten routes deliberately listed as public,
  // each with a comment explaining why it had to be, were in fact gated: a
  // guest could not open a profile, a department, a policy document or the
  // parcel tracker whose code is the only credential it has. It showed up
  // here because a shared link is precisely a stranger arriving at
  // `/user/<id>`.
  //
  // `fullPath` is empty when nothing matched; the location is then the honest
  // fallback, and an unmatched route is not public either way.
  final pattern = state.fullPath?.isNotEmpty == true
      ? state.fullPath!
      : location;
  final isPublic = _publicRoutes.contains(pattern);
  final isAuthenticated = auth.isAuthenticated;

  if (!isAuthenticated && !isPublic) {
    final from = Uri.encodeComponent(state.uri.toString());
    return '${RoutePaths.authRequired}?from=$from';
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
  if (isAdminRoute && auth.user?.isAdmin != true) {
    return RoutePaths.home;
  }

  // Inside the console, the role gets you through the door and the permission
  // decides which room. The dashboard needs `admin:dashboard`, which a support
  // agent does not hold — and the console's default path sent her there anyway,
  // so signing in as support opened a screen that could only 403. Land her on
  // the first destination she is actually allowed to use instead.
  if (isAdminRoute) {
    final permissions = auth.user?.permissions ?? const <String>{};
    final destination = AppRoleExperience.admin.navigation
        .where((item) => item.path == location)
        .firstOrNull;
    final required = destination?.permission;
    if (required != null &&
        permissions.isNotEmpty &&
        !permissions.contains(required)) {
      return _firstPermittedAdminPath(permissions) ?? RoutePaths.home;
    }
  }

  // Seller tools are explicit so `/seller-verification` remains available to
  // customers who are applying for seller access.
  final isSellerToolRoute = _matchesRouteGroup(location, _sellerToolRoutes);
  if (isSellerToolRoute && !_canUseSellerTools(role)) {
    return RoutePaths.home;
  }

  return null;
}

bool _matchesRouteGroup(String location, Set<String> routes) {
  return routes.any(
    (route) => location == route || location.startsWith('$route/'),
  );
}

bool _canUseSellerTools(UserRole? role) {
  return switch (role) {
    UserRole.seller ||
    UserRole.superAdmin ||
    UserRole.operationsAdmin ||
    UserRole.contentModerator ||
    UserRole.admin => true,
    _ => false,
  };
}

/// The first console destination this operator can open.
///
/// The navigation list is already ordered by how central the screen is to the
/// job, so walking it in order lands each staff role on something useful: the
/// dashboard for an administrator, the support queue for an agent, the finance
/// console for the accountant. `null` means the account holds a staff role but
/// no console permission at all, which is a misconfiguration rather than a
/// state to design a screen for — the caller sends her home.
String? _firstPermittedAdminPath(Set<String> permissions) {
  for (final item in AppRoleExperience.admin.navigation) {
    if (item.permission == null || permissions.contains(item.permission)) {
      return item.path;
    }
  }
  return null;
}
