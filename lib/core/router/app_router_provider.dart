import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/observability/breadcrumb_observers.dart';
import 'package:reem/core/router/app_shell.dart';
import 'package:reem/core/router/auth_guard.dart';
import 'package:reem/core/router/route_names.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/screens/admin_analytics_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_delivery_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_notification_analytics_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_orders_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_products_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_section_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_seller_applications_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:reem/features/admin/presentation/shell/admin_shell.dart';
import 'package:reem/features/admin_finance/presentation/screens/admin_finance_screen.dart';
import 'package:reem/features/ai_stylist/presentation/screens/ai_stylist_screen.dart';
import 'package:reem/features/ai_stylist/presentation/screens/style_preferences_screen.dart';
import 'package:reem/features/ai_stylist/presentation/screens/stylist_outfit_screen.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_state.dart';
import 'package:reem/features/auth/presentation/screens/account_recovery_screen.dart';
import 'package:reem/features/auth/presentation/screens/account_settings_screen.dart';
import 'package:reem/features/auth/presentation/screens/auth_required_screen.dart';
import 'package:reem/features/auth/presentation/screens/device_management_screen.dart';
import 'package:reem/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:reem/features/auth/presentation/screens/login_screen.dart';
import 'package:reem/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:reem/features/auth/presentation/screens/phone_change_screen.dart';
import 'package:reem/features/auth/presentation/screens/register_screen.dart';
import 'package:reem/features/auth/presentation/screens/security_settings_screen.dart';
import 'package:reem/features/auth/presentation/screens/seller_verification_screen.dart';
import 'package:reem/features/auth/presentation/screens/sign_in_code_screen.dart';
import 'package:reem/features/cart/presentation/screens/cart_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_details_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_media_gallery_screen.dart';
import 'package:reem/features/chat/presentation/screens/chats_screen.dart';
import 'package:reem/features/checkout/presentation/providers/orders_notifier.dart';
import 'package:reem/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:reem/features/checkout/presentation/screens/order_detail_screen.dart';
import 'package:reem/features/checkout/presentation/screens/orders_screen.dart';
import 'package:reem/features/closet/presentation/screens/add_personal_item_screen.dart';
import 'package:reem/features/closet/presentation/screens/closet_gap_screen.dart';
import 'package:reem/features/closet/presentation/screens/closet_item_screen.dart';
import 'package:reem/features/closet/presentation/screens/closet_look_screen.dart';
import 'package:reem/features/closet/presentation/screens/closet_looks_screen.dart';
import 'package:reem/features/closet/presentation/screens/closet_today_screen.dart';
import 'package:reem/features/closet/presentation/screens/my_closet_screen.dart';
import 'package:reem/features/courier/presentation/screens/courier_day_screen.dart';
import 'package:reem/features/create/presentation/screens/add_post_screen.dart';
import 'package:reem/features/create/presentation/screens/add_story_screen.dart';
import 'package:reem/features/discovery/domain/entities/product_collection.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/discovery/presentation/screens/collection_screen.dart';
import 'package:reem/features/discovery/presentation/widgets/product_collection_title.dart';
import 'package:reem/features/experience/presentation/screens/experience_surface_screen.dart';
import 'package:reem/features/home/presentation/screens/categories_screen.dart';
import 'package:reem/features/home/presentation/screens/category_screen.dart';
import 'package:reem/features/home/presentation/screens/home_screen.dart';
import 'package:reem/features/invoices/presentation/screens/invoice_screen.dart';
import 'package:reem/features/invoices/presentation/screens/order_invoices_screen.dart';
import 'package:reem/features/market/presentation/screens/bundle_screen.dart';
import 'package:reem/features/market/presentation/screens/bundles_screen.dart';
import 'package:reem/features/market/presentation/screens/drops_screen.dart';
import 'package:reem/features/market/presentation/screens/missions_screen.dart';
import 'package:reem/features/market/presentation/screens/resale_market_screen.dart';
import 'package:reem/features/market/presentation/screens/seller_market_screen.dart';
import 'package:reem/features/market/presentation/screens/wardrobe_care_screen.dart';
import 'package:reem/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:reem/features/product_details/presentation/screens/product_details_screen.dart';
import 'package:reem/features/profile/presentation/screens/favorites_screen.dart';
import 'package:reem/features/profile/presentation/screens/profile_screen.dart';
import 'package:reem/features/reputation/presentation/screens/my_reviews_screen.dart';
import 'package:reem/features/returns/presentation/screens/return_request_screen.dart';
import 'package:reem/features/rooms/presentation/screens/compare_screen.dart';
import 'package:reem/features/rooms/presentation/screens/purchase_plan_screen.dart';
import 'package:reem/features/rooms/presentation/screens/room_join_screen.dart';
import 'package:reem/features/rooms/presentation/screens/room_screen.dart';
import 'package:reem/features/rooms/presentation/screens/rooms_screen.dart';
import 'package:reem/features/search/presentation/screens/search_screen.dart';
import 'package:reem/features/seller_analytics/presentation/screens/seller_analytics_screen.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_home_screen.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_profile_screen.dart';
import 'package:reem/features/seller_earnings/presentation/screens/seller_earnings_screen.dart';
import 'package:reem/features/seller_intelligence/presentation/screens/demand_radar_screen.dart';
import 'package:reem/features/seller_intelligence/presentation/screens/product_intelligence_screen.dart';
import 'package:reem/features/seller_intelligence/presentation/screens/seller_health_screen.dart';
import 'package:reem/features/seller_orders/presentation/screens/seller_order_detail_screen.dart';
import 'package:reem/features/seller_orders/presentation/screens/seller_orders_screen.dart';
import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/presentation/screens/my_products_screen.dart';
import 'package:reem/features/seller_products/presentation/screens/product_form_screen.dart';
import 'package:reem/features/seller_returns/presentation/screens/seller_return_detail_screen.dart';
import 'package:reem/features/seller_returns/presentation/screens/seller_returns_screen.dart';
import 'package:reem/features/seller_reviews/presentation/screens/seller_reviews_screen.dart';
import 'package:reem/features/settings/presentation/screens/adresses_screen.dart';
import 'package:reem/features/settings/presentation/screens/appearance_screen.dart';
import 'package:reem/features/settings/presentation/screens/coupons_screen.dart';
import 'package:reem/features/settings/presentation/screens/language_screen.dart';
import 'package:reem/features/settings/presentation/screens/notification_inbox_screen.dart';
import 'package:reem/features/settings/presentation/screens/notifications_screen.dart';
import 'package:reem/features/settings/presentation/screens/payment_methods_screen.dart';
import 'package:reem/features/settings/presentation/screens/rewards_screen.dart';
import 'package:reem/features/settings/presentation/screens/settings_screen.dart';
import 'package:reem/features/shipment_tracking/presentation/screens/shipment_tracking_screen.dart';
import 'package:reem/features/social/presentation/screens/admin_content_screen.dart';
import 'package:reem/features/social/presentation/screens/content_composer_screen.dart';
import 'package:reem/features/social/presentation/screens/content_studio_screen.dart';
import 'package:reem/features/social/presentation/screens/reels_screen.dart';
import 'package:reem/features/social/presentation/screens/social_feed_screen.dart';
import 'package:reem/features/splash/presentation/screens/splash_screen.dart';
import 'package:reem/features/stories/presentation/screens/story_viewer_screen.dart';
import 'package:reem/features/trends/presentation/screens/admin_trends_screen.dart';
import 'package:reem/features/trends/presentation/screens/seller_trends_screen.dart';
import 'package:reem/features/user_profile/presentation/screens/edit_profile_screen.dart';
import 'package:reem/features/user_profile/presentation/screens/follow_list_screen.dart';
import 'package:reem/features/user_profile/presentation/screens/user_profile_screen.dart';
import 'package:reem/features/value/presentation/screens/admin_value_screen.dart';
import 'package:reem/features/value/presentation/screens/value_screen.dart';
import 'package:reem/features/visual_search/presentation/screens/visual_search_screen.dart';
import 'package:reem/features/wallet/presentation/screens/wallet_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

// final _publicRoutes = {
//   RoutePaths.splash,
//   RoutePaths.onboarding,
//   RoutePaths.login,
//   RoutePaths.register,
//   RoutePaths.forgotPassword,
// };

/// Re-evaluates the guard when the session changes, without rebuilding the
/// router.
///
/// The distinction is the whole fix. The provider used to `watch` the auth
/// state, so **every** change to it — including the `isLoading` flag flicking
/// on and off during an ordinary request — constructed a brand-new [GoRouter],
/// and a new router starts at its `initialLocation`. The navigation stack was
/// silently thrown away and the app jumped to Home.
///
/// Nothing noticed while every journey was a single screen: sign in, land on
/// Home, which is where the reset sent you anyway. It surfaced the moment a
/// journey had two steps — ask for a code, then type it — because asking for
/// the code is itself a request, and the loading flag it sets destroyed the
/// screen that was about to show her the code.
///
/// So the router is built once and this listenable pokes it. It deliberately
/// only fires on the three things the guard actually reads; a spurious refresh
/// is cheap but not free, and this keeps redirect evaluation proportional to
/// real session changes rather than to network chatter.
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    _subscription = ref.listen<AuthState>(authNotifierProvider, (
      previous,
      next,
    ) {
      final changed =
          previous?.isInitialized != next.isInitialized ||
          previous?.isAuthenticated != next.isAuthenticated ||
          previous?.isGuest != next.isGuest ||
          previous?.user?.role != next.user?.role;
      if (changed) notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// Folds a `reem://` link's authority back into its path.
///
/// The gotcha this exists for: in `reem://rooms/join/abc` the first segment is
/// the URI's *authority*, not part of its path — `Uri.parse` gives host
/// `rooms` and path `/join/abc`. GoRouter matches on the path alone, so an
/// invite arriving from the OS looked like a request for `/join/abc`, matched
/// nothing, and dropped the woman who tapped it on the 404 page.
///
/// Returns null for anything already shaped like a route, which is every
/// in-app navigation and the `reem:///rooms/join/abc` spelling with an empty
/// authority.
///
/// Called from two places now: the router's own redirect, for a link the
/// operating system hands the app, and the push coordinator, for the
/// `deep_link` a notification carries. One function, because a notification
/// that opens a different screen than the same link pasted into a browser is
/// a bug waiting to be found by a customer.
String? deepLinkPath(Uri uri) {
  if (uri.scheme != 'reem' || uri.host.isEmpty) {
    return null;
  }
  final rebuilt = Uri(
    path: '/${uri.host}${uri.path}',
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  );
  return rebuilt.toString();
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    // Debug only. GoRouter's diagnostics print every redirect, every match
    // and every full location to the device log, and `debugLogDiagnostics`
    // is not compiled out of a release build — a shipped app was narrating
    // the whole navigation stack, path parameters included, to logcat.
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    // Route changes become breadcrumbs, so a crash report says which screens
    // she passed through on the way to it. Names only — never a parameter.
    observers: [NavigationBreadcrumbs()],
    // Read, not watch: the guard needs the state at the moment it runs, and
    // `refreshListenable` is what tells the router to run it again.
    redirect: (context, state) {
      final normalised = deepLinkPath(state.uri);
      if (normalised != null) {
        return normalised;
      }
      return authGuard(context, state, ref.read(authNotifierProvider));
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: RoutePaths.authRequired,
        name: RouteNames.authRequired,
        builder: (context, state) =>
            AuthRequiredScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        // Not an entry point: `phone` and `ticket` come from the verified code
        // step, and the server refuses to create an account without the
        // ticket. Reaching this path with neither sends her back to the front
        // door rather than to a form that cannot succeed.
        redirect: (context, state) {
          final params = state.uri.queryParameters;
          final hasProof =
              (params['phone']?.isNotEmpty ?? false) &&
              (params['ticket']?.isNotEmpty ?? false);
          return hasProof ? null : RoutePaths.login;
        },
        builder: (context, state) => RegisterScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          registrationTicket: state.uri.queryParameters['ticket'] ?? '',
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: RoutePaths.signInCode,
        name: RouteNames.signInCode,
        // The challenge travels in `extra` rather than the query string: it is
        // a whole object, and the two-digit match code has no business being
        // written into a URL and a browser history.
        builder: (context, state) => SignInCodeScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          challenge: state.extra is OtpChallenge
              ? state.extra as OtpChallenge
              : null,
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.otpVerification,
        name: RouteNames.otpVerification,
        builder: (context, state) => OtpVerificationScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          purpose: _otpPurposeFromWire(state.uri.queryParameters['purpose']),
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: RoutePaths.accountSettings,
        name: RouteNames.accountSettings,
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.deviceManagement,
        name: RouteNames.deviceManagement,
        builder: (context, state) => const DeviceManagementScreen(),
      ),
      GoRoute(
        path: RoutePaths.securitySettings,
        name: RouteNames.securitySettings,
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.phoneChange,
        name: RouteNames.phoneChange,
        builder: (context, state) => const PhoneChangeScreen(),
      ),
      GoRoute(
        path: RoutePaths.accountRecovery,
        name: RouteNames.accountRecovery,
        builder: (context, state) => const AccountRecoveryScreen(),
      ),
      GoRoute(
        path: RoutePaths.sellerVerification,
        name: RouteNames.sellerVerification,
        builder: (context, state) => const SellerVerificationScreen(),
      ),
      GoRoute(
        path: RoutePaths.checkout,
        name: RouteNames.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: RoutePaths.orderDetail,
        name: RouteNames.orderDetail,
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.collection,
        name: RouteNames.collection,
        builder: (context, state) {
          final collection = ProductCollectionX.fromKey(
            state.pathParameters['key'] ?? 'trending',
          );
          return CollectionScreen(
            provider: collectionProductsProvider(collection),
            title: collection.titleOf(context.l10n),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.courierDay,
        name: RouteNames.courierDay,
        builder: (context, state) => const CourierDayScreen(),
      ),
      // Q64 — tracking by code. The code is the credential, so this sits
      // outside the auth guard: a customer may hand it to whoever is waiting
      // for the parcel without handing over her account.
      GoRoute(
        path: RoutePaths.shipmentTracking,
        name: RouteNames.shipmentTracking,
        builder: (context, state) => ShipmentTrackingScreen(
          trackingCode: state.pathParameters['code'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.orderInvoices,
        name: RouteNames.orderInvoices,
        builder: (context, state) =>
            OrderInvoicesScreen(orderId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.returnRequest,
        name: RouteNames.returnRequest,
        builder: (context, state) => ReturnRequestScreen(
          sellerOrderId: state.pathParameters['sellerOrderId'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.invoice,
        name: RouteNames.invoice,
        builder: (context, state) =>
            InvoiceScreen(invoiceId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.productDetails,
        name: RouteNames.productDetails,
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return ProductDetailsScreen(productId: id);
        },
      ),

      // Reem AI Stylist. Full-screen rather than a shell tab: a conversation
      // owns the whole surface, and the bottom bar competing with the composer
      // for the same thumb is the wrong trade.
      GoRoute(
        path: RoutePaths.stylist,
        name: RouteNames.stylist,
        builder: (context, state) => const AiStylistScreen(),
      ),
      GoRoute(
        path: RoutePaths.stylistConversation,
        name: RouteNames.stylistConversation,
        builder: (context, state) =>
            AiStylistScreen(conversationId: state.pathParameters['id']),
      ),
      GoRoute(
        path: RoutePaths.stylistPreferences,
        name: RouteNames.stylistPreferences,
        builder: (context, state) => const StylePreferencesScreen(),
      ),
      GoRoute(
        path: RoutePaths.stylistOutfit,
        name: RouteNames.stylistOutfit,
        builder: (context, state) =>
            StylistOutfitScreen(outfitId: state.pathParameters['id'] ?? ''),
      ),
      // Reem Closet. Full-screen: her wardrobe is a place she goes into rather
      // than a shelf she glances at, and the grid wants the whole surface.
      //
      // Note what is absent — every one of these is authenticated and none has
      // a shareable form. A list of the clothes a woman owns, photographed in
      // her home, has no public URL by design.
      // Reem Market Evolution. Full-screen destinations, none of them in the
      // shell: a bundle and a drop are each one thing she came to look at, and
      // a bottom bar competing with them is the same trade the closet and the
      // rooms already refused.
      GoRoute(
        path: RoutePaths.marketBundles,
        name: RouteNames.marketBundles,
        builder: (context, state) => const BundlesScreen(),
      ),
      GoRoute(
        path: RoutePaths.marketBundle,
        name: RouteNames.marketBundle,
        builder: (context, state) =>
            BundleScreen(bundleId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.marketDrops,
        name: RouteNames.marketDrops,
        builder: (context, state) => const DropsScreen(),
      ),
      GoRoute(
        path: RoutePaths.marketMissions,
        name: RouteNames.marketMissions,
        builder: (context, state) => const MissionsScreen(),
      ),
      GoRoute(
        path: RoutePaths.marketWardrobe,
        name: RouteNames.marketWardrobe,
        builder: (context, state) => const WardrobeCareScreen(),
      ),
      GoRoute(
        path: RoutePaths.marketResale,
        name: RouteNames.marketResale,
        builder: (context, state) => const ResaleMarketScreen(),
      ),
      GoRoute(
        path: RoutePaths.sellerMarket,
        name: RouteNames.sellerMarket,
        builder: (context, state) => const SellerMarketScreen(),
      ),
      GoRoute(
        path: RoutePaths.closet,
        name: RouteNames.closet,
        builder: (context, state) => const MyClosetScreen(),
      ),
      GoRoute(
        path: RoutePaths.closetToday,
        name: RouteNames.closetToday,
        builder: (context, state) => const ClosetTodayScreen(),
      ),
      GoRoute(
        path: RoutePaths.closetAddItem,
        name: RouteNames.closetAddItem,
        builder: (context, state) => const AddPersonalItemScreen(),
      ),
      GoRoute(
        path: RoutePaths.closetLooks,
        name: RouteNames.closetLooks,
        builder: (context, state) => const ClosetLooksScreen(),
      ),
      GoRoute(
        path: RoutePaths.closetLook,
        name: RouteNames.closetLook,
        builder: (context, state) =>
            ClosetLookScreen(lookId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.closetItem,
        name: RouteNames.closetItem,
        builder: (context, state) =>
            ClosetItemScreen(itemId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.closetGap,
        name: RouteNames.closetGap,
        builder: (context, state) =>
            ClosetGapScreen(gapId: state.pathParameters['id'] ?? ''),
      ),
      // The cart is no longer a destination — Rooms took its tab, because what
      // she is in the middle of is a set of decisions rather than a basket. It
      // stays reachable from the profile menu for the one-tap purchase that
      // needs no deliberation, which is what a pushed route is for.
      GoRoute(
        path: RoutePaths.cart,
        name: RouteNames.cart,
        builder: (context, state) => const CartScreen(),
      ),
      // Before `/rooms/:id`. GoRouter matches in declaration order and `:id`
      // is greedy, so declared after this one it would swallow `join` and try
      // to open a room whose id is the word "join".
      GoRoute(
        path: RoutePaths.roomJoin,
        name: RouteNames.roomJoin,
        builder: (context, state) =>
            RoomJoinScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.room,
        name: RouteNames.room,
        builder: (context, state) =>
            RoomScreen(roomId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.roomPlan,
        name: RouteNames.roomPlan,
        builder: (context, state) =>
            PurchasePlanScreen(roomId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.roomCompare,
        name: RouteNames.roomCompare,
        builder: (context, state) => CompareScreen(
          roomId: state.pathParameters['id'] ?? '',
          decisionId: state.pathParameters['decisionId'] ?? '',
        ),
      ),
      // Reem Value. Reachable from the profile and from home; full-screen
      // because reading where you stand is not a glance.
      GoRoute(
        path: RoutePaths.value,
        name: RouteNames.value,
        builder: (context, state) => const ValueScreen(),
      ),
      // Reem Visual Shopping. Full-screen for the same reason the stylist is:
      // she is comparing a photograph against a grid, and a bottom bar eating
      // the last row of that grid is the wrong trade.
      GoRoute(
        path: RoutePaths.visualSearch,
        name: RouteNames.visualSearch,
        builder: (context, state) => const VisualSearchScreen(),
      ),
      GoRoute(
        path: RoutePaths.visualSearchSession,
        name: RouteNames.visualSearchSession,
        builder: (context, state) =>
            VisualSearchScreen(sessionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: RoutePaths.addPost,
        name: RouteNames.addPost,
        builder: (context, state) => const AddPostScreen(),
      ),
      GoRoute(
        path: RoutePaths.addStory,
        name: RouteNames.addStory,
        builder: (context, state) => const AddStoryScreen(),
      ),

      // ── The social platform ─────────────────────────────────────────────
      //
      // `/compose` is the composer for everybody — one screen that asks which
      // format, because a post, a reel and a story are one object with three
      // shapes. `/add-post` and `/add-story` above stay routed while the
      // seller app still links to them.
      GoRoute(
        path: RoutePaths.compose,
        name: RouteNames.compose,
        // `?format=post|reel|story` — which shape she chose before arriving.
        builder: (context, state) => ContentComposerScreen(
          initialFormat: state.uri.queryParameters['format'],
        ),
      ),
      GoRoute(
        path: RoutePaths.socialFeed,
        name: RouteNames.socialFeed,
        builder: (context, state) => const SocialFeedScreen(),
      ),
      GoRoute(
        path: RoutePaths.reels,
        name: RouteNames.reels,
        builder: (context, state) => const ReelsScreen(),
      ),
      GoRoute(
        path: RoutePaths.contentStudio,
        name: RouteNames.contentStudio,
        builder: (context, state) => const ContentStudioScreen(),
      ),
      GoRoute(
        path: RoutePaths.category,
        name: RouteNames.category,
        builder: (context, state) {
          final category = state.pathParameters['category'] ?? '';
          return CategoryScreen(category: category);
        },
      ),
      GoRoute(
        path: RoutePaths.categories,
        name: RouteNames.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationInboxScreen(),
      ),
      GoRoute(
        path: RoutePaths.notificationPreferences,
        name: RouteNames.notificationPreferences,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.favorites,
        name: RouteNames.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.addresses,
        name: RouteNames.addresses,
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: RoutePaths.paymentMethods,
        name: RouteNames.paymentMethods,
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: RoutePaths.appearance,
        name: RouteNames.appearance,
        builder: (context, state) => const AppearanceScreen(),
      ),
      GoRoute(
        path: RoutePaths.language,
        name: RouteNames.language,
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: RoutePaths.coupons,
        name: RouteNames.coupons,
        builder: (context, state) => const CouponsScreen(),
      ),
      GoRoute(
        path: RoutePaths.myReviews,
        name: RouteNames.myReviews,
        builder: (context, state) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: RoutePaths.rewards,
        name: RouteNames.rewards,
        builder: (context, state) => const RewardsScreen(),
      ),
      GoRoute(
        path: RoutePaths.wallet,
        name: RouteNames.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: RoutePaths.sellerEarnings,
        name: RouteNames.sellerEarnings,
        builder: (context, state) => const SellerEarningsScreen(),
      ),
      GoRoute(
        path: RoutePaths.sellerReviews,
        name: RouteNames.sellerReviews,
        builder: (context, state) => const SellerReviewsScreen(),
      ),
      GoRoute(
        path: RoutePaths.sellerReturns,
        name: RouteNames.sellerReturns,
        builder: (context, state) => const SellerReturnsScreen(),
      ),
      GoRoute(
        // After the queue, so `/seller/returns` is not swallowed by `:id`.
        path: RoutePaths.sellerReturnDetail,
        name: RouteNames.sellerReturnDetail,
        builder: (context, state) =>
            SellerReturnDetailScreen(returnId: state.pathParameters['id']!),
      ),
      GoRoute(
        // The CUSTOMER's purchase history, pushed from her profile. It is no
        // longer a shell branch: it never was one of her tabs, and being one
        // is what let the seller's Orders tab land on it.
        path: RoutePaths.orders,
        name: RouteNames.orders,
        // `?bucket=cancelled` opens the pile her profile counted. An unknown
        // value falls back to everything rather than to an empty screen.
        builder: (context, state) => OrdersScreen(
          initialBucket: OrderBucket.fromWire(
            state.uri.queryParameters['bucket'],
          ),
        ),
      ),
      GoRoute(
        // Declared after the queue so `/seller/orders` is not swallowed by the
        // `:id` segment.
        path: RoutePaths.sellerOrderDetail,
        name: RouteNames.sellerOrderDetail,
        builder: (context, state) =>
            SellerOrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        name: RouteNames.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.userProfile,
        name: RouteNames.userProfile,
        builder: (context, state) =>
            UserProfileScreen(userId: state.pathParameters['id']),
      ),
      // One boutique's whole shelf. `CollectionScreen` takes any collection
      // provider and already pages, switches shape, favourites and adds to the
      // bag — `sellerProductsProvider` had simply never been handed to it.
      GoRoute(
        path: RoutePaths.sellerProducts,
        name: RouteNames.sellerProducts,
        builder: (context, state) {
          final sellerId = state.pathParameters['id'] ?? '';
          return CollectionScreen(
            provider: sellerProductsProvider(sellerId),
            title: state.uri.queryParameters['name'] ?? context.l10n.products,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.followList,
        name: RouteNames.followList,
        builder: (context, state) => FollowListScreen(
          userId: state.pathParameters['id']!,
          kind: state.pathParameters['kind'] == 'followers'
              ? FollowListKind.followers
              : FollowListKind.following,
        ),
      ),
      GoRoute(
        path: RoutePaths.productForm,
        name: RouteNames.productForm,
        builder: (context, state) =>
            ProductFormScreen(product: state.extra as ManagedProduct?),
      ),
      GoRoute(
        path: RoutePaths.storyViewer,
        name: RouteNames.storyViewer,
        builder: (context, state) {
          final args = state.extra as StoryViewerArgs?;
          return StoryViewerScreen(
            stories: args?.stories ?? const [],
            initialIndex: args?.initialIndex ?? 0,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.admin,
        name: RouteNames.adminDashboard,
        builder: (context, state) =>
            const AdminShell(child: AdminDashboardScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminOrders,
        name: RouteNames.adminOrders,
        builder: (context, state) =>
            const AdminShell(child: AdminOrdersScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminProducts,
        name: RouteNames.adminProducts,
        builder: (context, state) =>
            const AdminShell(child: AdminProductsScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminUsers,
        name: RouteNames.adminUsers,
        builder: (context, state) =>
            const AdminShell(child: AdminUsersScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminSellerApplications,
        name: RouteNames.adminSellerApplications,
        builder: (context, state) =>
            const AdminShell(child: AdminSellerApplicationsScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminDelivery,
        name: RouteNames.adminDelivery,
        builder: (context, state) =>
            const AdminShell(child: AdminDeliveryScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminSellers,
        name: RouteNames.adminSellers,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['sellers']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminFinancials,
        name: RouteNames.adminFinancials,
        builder: (context, state) =>
            const AdminShell(child: AdminFinanceScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminCommissions,
        name: RouteNames.adminCommissions,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(
            config: adminSectionConfigs['commissions']!,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminAnalytics,
        name: RouteNames.adminAnalytics,
        builder: (context, state) =>
            const AdminShell(child: AdminAnalyticsScreen()),
      ),
      // Market intelligence sits beside the analytics console rather than
      // inside it: one answers what happened, the other what is about to.
      GoRoute(
        path: RoutePaths.adminTrends,
        name: RouteNames.adminTrends,
        builder: (context, state) =>
            const AdminShell(child: AdminTrendsScreen()),
      ),
      // Reem Value's console sits beside market intelligence rather than under
      // settings: both are engines with a policy behind them, and both are
      // operated rather than configured.
      GoRoute(
        path: RoutePaths.adminValue,
        name: RouteNames.adminValue,
        builder: (context, state) =>
            const AdminShell(child: AdminValueScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminReports,
        name: RouteNames.adminReports,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['reports']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminModeration,
        name: RouteNames.adminModeration,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['moderation']!),
        ),
      ),
      // Social content gets a purpose-built screen rather than the generic
      // section table: the queue needs a thumbnail, the author's kind, and a
      // removal dialog that will not submit without a reason — none of which
      // `AdminSectionScreen` can express. Same precedent as
      // `AdminSellerApplicationsScreen`.
      GoRoute(
        path: RoutePaths.adminContent,
        name: RouteNames.adminContent,
        builder: (context, state) =>
            const AdminShell(child: AdminContentScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminSupport,
        name: RouteNames.adminSupport,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['support']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminAuditLogs,
        name: RouteNames.adminAuditLogs,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['audit']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminSystemSettings,
        name: RouteNames.adminSystemSettings,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['settings']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminCampaigns,
        name: RouteNames.adminCampaigns,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['campaigns']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminNotificationAnalytics,
        name: RouteNames.adminNotificationAnalytics,
        builder: (context, state) => const AdminShell(
          child: AdminNotificationAnalyticsScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.chatDetails,
        name: RouteNames.chatDetails,
        builder: (context, state) {
          final chatId = state.uri.queryParameters['id'] ?? '';
          return ChatDetailsScreen(chatId: chatId);
        },
      ),
      GoRoute(
        path: RoutePaths.chatMediaGallery,
        name: RouteNames.chatMediaGallery,
        builder: (context, state) => ChatMediaGalleryScreen(
          chatId: state.uri.queryParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.chats,
        name: RouteNames.chats,
        builder: (context, state) => const ChatsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.search,
                name: RouteNames.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          // Reem Rooms holds the third tab. It has to be a branch, not a
          // top-level route: a tab reached with `context.go` tears the shell
          // down, and she arrives at a full-screen room with no bottom bar and
          // nothing to press to get back to Home or Search.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.rooms,
                name: RouteNames.rooms,
                builder: (context, state) => const RoomsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.activity,
                name: RouteNames.activity,
                builder: (context, state) => const ExperienceSurfaceScreen(
                  surface: ExperienceSurface.activity,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.sellerDashboard,
                name: RouteNames.sellerDashboard,
                builder: (context, state) => const SellerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.myProducts,
                name: RouteNames.myProducts,
                builder: (context, state) => const MyProductsScreen(),
              ),
            ],
          ),
          // Her order queue — the screen she works a sale from. This branch
          // used to hold `/orders`, the CUSTOMER's purchase history, so the
          // seller's Orders tab opened someone else's receipts while her own
          // queue sat outside the shell with no navigation around it.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.sellerOrders,
                name: RouteNames.sellerOrders,
                builder: (context, state) => const SellerOrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.sellerAnalytics,
                name: RouteNames.sellerAnalytics,
                builder: (context, state) => const SellerAnalyticsScreen(),
              ),
              // A sibling in the same branch rather than a tab of its own:
              // the seller shell already carries as many tabs as a thumb can
              // reach, and both pages belong to the same question.
              GoRoute(
                path: RoutePaths.sellerTrends,
                name: RouteNames.sellerTrends,
                builder: (context, state) => const SellerTrendsScreen(),
              ),
              // The three intelligence pages sit in the same branch for the
              // same reason: they answer the same question at three ranges —
              // the market, the listing, the shop — and a tab each would cost
              // more thumb than the whole feature is worth.
              GoRoute(
                path: RoutePaths.sellerRadar,
                name: RouteNames.sellerRadar,
                builder: (context, state) => const DemandRadarScreen(),
              ),
              GoRoute(
                path: RoutePaths.sellerProductIntelligence,
                name: RouteNames.sellerProductIntelligence,
                builder: (context, state) => const ProductIntelligenceScreen(),
              ),
              GoRoute(
                path: RoutePaths.sellerHealth,
                name: RouteNames.sellerHealth,
                builder: (context, state) => const SellerHealthScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.sellerStore,
                name: RouteNames.sellerStore,
                builder: (context, state) => const SellerProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

OtpPurpose _otpPurposeFromWire(String? value) => switch (value) {
  'password_reset' => OtpPurpose.passwordReset,
  'device_verification' => OtpPurpose.deviceVerification,
  'login' => OtpPurpose.login,
  'phone_change' => OtpPurpose.phoneChange,
  'account_recovery' => OtpPurpose.accountRecovery,
  _ => OtpPurpose.phoneVerification,
};
