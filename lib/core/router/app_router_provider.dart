import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/router/auth_guard.dart';
import 'package:reem/features/admin/presentation/screens/admin_analytics_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_orders_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_products_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:reem/features/admin/presentation/shell/admin_shell.dart';
import 'package:reem/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:reem/features/auth/presentation/screens/login_screen.dart';
import 'package:reem/features/auth/presentation/screens/register_screen.dart';
import 'package:reem/features/chat/presentation/screens/chats_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_details_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_media_gallery_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_profile_screen.dart';
import 'package:reem/features/chat/presentation/screens/story_share_chat_screen.dart';
import 'package:reem/features/chat/presentation/screens/video_call_screen.dart';
import 'package:reem/features/home/presentation/screens/home_screen.dart';
import 'package:reem/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:reem/features/product_details/presentation/screens/product_details_screen.dart';
import 'package:reem/features/profile/presentation/screens/favorites_screen.dart';
import 'package:reem/features/profile/presentation/screens/my_orders_screen.dart';
import 'package:reem/features/profile/presentation/screens/profile_screen.dart';
import 'package:reem/features/settings/presentation/screens/adresses_screen.dart';
import 'package:reem/features/settings/presentation/screens/appearance_screen.dart';
import 'package:reem/features/settings/presentation/screens/coupons_screen.dart';
import 'package:reem/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:reem/features/settings/presentation/screens/language_screen.dart';
import 'package:reem/features/settings/presentation/screens/notifications_screen.dart';
import 'package:reem/features/settings/presentation/screens/payment_methods_screen.dart';
import 'package:reem/features/settings/presentation/screens/rewards_screen.dart';
import 'package:reem/features/settings/presentation/screens/settings_screen.dart';
import 'package:reem/features/splash/presentation/screens/splash_screen.dart';

import 'app_shell.dart';
import 'route_names.dart';
import 'route_paths.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

// final _publicRoutes = {
//   RoutePaths.splash,
//   RoutePaths.onboarding,
//   RoutePaths.login,
//   RoutePaths.register,
//   RoutePaths.forgotPassword,
// };

final goRouterProvider = Provider<GoRouter>((ref) {
  // final auth = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: true,
    // redirect: (context, state) => authGuard(context, state, ref),
    // redirect: (context, state) {
    //   if (!auth.isInitialized) return null;

    //   final location = state.matchedLocation;
    //   final isPublic = _publicRoutes.contains(location);
    //   final isAuthenticated = auth.isAuthenticated;

    //   if (!isAuthenticated && !isPublic) return RoutePaths.login;
    //   if (isAuthenticated &&
    //       (location == RoutePaths.login ||
    //           location == RoutePaths.register ||
    //           location == RoutePaths.forgotPassword)) {
    //     return RoutePaths.home;
    //   }
    //   return null;
    // },
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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.orders,
        name: RouteNames.orders,
        builder: (context, state) => const MyOrdersScreen(),
      ),
      GoRoute(
        path: RoutePaths.productDetails,
        name: RouteNames.productDetails,
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return ProductDetailsScreen(productId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        name: RouteNames.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsScreen(),
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
        path: RoutePaths.rewards,
        name: RouteNames.rewards,
        builder: (context, state) => const RewardsScreen(),
      ),
      GoRoute(
        path: RoutePaths.admin,
        name: RouteNames.adminDashboard,
        builder: (context, state) => const AdminShell(child: AdminDashboardScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminOrders,
        name: RouteNames.adminOrders,
        builder: (context, state) => const AdminShell(child: AdminOrdersScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminProducts,
        name: RouteNames.adminProducts,
        builder: (context, state) => const AdminShell(child: AdminProductsScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminUsers,
        name: RouteNames.adminUsers,
        builder: (context, state) => const AdminShell(child: AdminUsersScreen()),
      ),
      GoRoute(
        path: RoutePaths.adminAnalytics,
        name: RouteNames.adminAnalytics,
        builder: (context, state) => const AdminShell(child: AdminAnalyticsScreen()),
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
        builder: (context, state) => const ChatMediaGalleryScreen(),
      ),
      GoRoute(
        path: RoutePaths.chatProfile,
        name: RouteNames.chatProfile,
        builder: (context, state) => const ChatProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.chats,
        name: RouteNames.chats,
        builder: (context, state) => const ChatsScreen(),
      ),
      GoRoute(
        path: RoutePaths.storyShareChat,
        name: RouteNames.storyShareChat,
        builder: (context, state) => const StoryShareChatScreen(),
      ),
      GoRoute(
        path: RoutePaths.videoCall,
        name: RouteNames.videoCall,
        builder: (context, state) => const VideoCallScreen(),
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
                path: RoutePaths.favorites,
                name: RouteNames.favorites,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.settings,
                name: RouteNames.settings,
                builder: (context, state) => const SettingsScreen(),
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
        ],
      ),
    ],
  );
});
