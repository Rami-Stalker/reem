import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/router/auth_guard.dart';
import 'package:reem/features/admin/presentation/screens/admin_analytics_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_orders_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_products_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_section_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/shell/admin_shell.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:reem/features/auth/presentation/screens/login_screen.dart';
import 'package:reem/features/auth/presentation/screens/account_settings_screen.dart';
import 'package:reem/features/auth/presentation/screens/device_management_screen.dart';
import 'package:reem/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:reem/features/auth/presentation/screens/register_screen.dart';
import 'package:reem/features/auth/presentation/screens/security_settings_screen.dart';
import 'package:reem/features/auth/presentation/screens/seller_verification_screen.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/user_profile/presentation/screens/edit_profile_screen.dart';
import 'package:reem/features/user_profile/presentation/screens/user_profile_screen.dart';
import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_home_screen.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_profile_screen.dart';
import 'package:reem/features/seller_products/presentation/screens/my_products_screen.dart';
import 'package:reem/features/seller_products/presentation/screens/product_form_screen.dart';
import 'package:reem/features/stories/presentation/screens/story_viewer_screen.dart';
import 'package:reem/features/cart/presentation/screens/cart_screen.dart';
import 'package:reem/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:reem/features/checkout/presentation/screens/orders_screen.dart';
import 'package:reem/features/checkout/presentation/screens/order_detail_screen.dart';
import 'package:reem/features/discovery/domain/entities/product_collection.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/discovery/presentation/screens/collection_screen.dart';
import 'package:reem/features/experience/presentation/screens/experience_surface_screen.dart';
import 'package:reem/features/chat/presentation/screens/chats_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_details_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_media_gallery_screen.dart';
import 'package:reem/features/chat/presentation/screens/chat_profile_screen.dart';
import 'package:reem/features/chat/presentation/screens/story_share_chat_screen.dart';
import 'package:reem/features/chat/presentation/screens/video_call_screen.dart';
import 'package:reem/features/create/presentation/screens/add_post_screen.dart';
import 'package:reem/features/create/presentation/screens/add_story_screen.dart';
import 'package:reem/features/home/presentation/screens/categories_screen.dart';
import 'package:reem/features/home/presentation/screens/category_screen.dart';
import 'package:reem/features/home/presentation/screens/home_screen.dart';
import 'package:reem/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:reem/features/product_details/presentation/screens/product_details_screen.dart';
import 'package:reem/features/search/presentation/screens/search_screen.dart';
import 'package:reem/features/profile/presentation/screens/favorites_screen.dart';
import 'package:reem/features/profile/presentation/screens/profile_screen.dart';
import 'package:reem/features/settings/presentation/screens/adresses_screen.dart';
import 'package:reem/features/settings/presentation/screens/appearance_screen.dart';
import 'package:reem/features/settings/presentation/screens/coupons_screen.dart';
import 'package:reem/features/settings/presentation/screens/language_screen.dart';
import 'package:reem/features/settings/presentation/screens/notifications_screen.dart';
import 'package:reem/features/settings/presentation/screens/payment_methods_screen.dart';
import 'package:reem/features/settings/presentation/screens/rewards_screen.dart';
import 'package:reem/features/settings/presentation/screens/settings_screen.dart';
import 'package:reem/features/splash/presentation/screens/splash_screen.dart';

import 'app_shell.dart';
import '../experience/role_experience.dart';
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
  // Watch auth so the router re-evaluates redirects when the session changes
  // (login / logout / token-restore), enabling persistent login + role gating.
  final auth = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: true,
    redirect: (context, state) => authGuard(context, state, auth),
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
        path: RoutePaths.otpVerification,
        name: RouteNames.otpVerification,
        builder: (context, state) => OtpVerificationScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          purpose: _otpPurposeFromWire(state.uri.queryParameters['purpose']),
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
            title: collection.title,
          );
        },
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
        path: RoutePaths.addPost,
        name: RouteNames.addPost,
        builder: (context, state) => const AddPostScreen(),
      ),
      GoRoute(
        path: RoutePaths.addStory,
        name: RouteNames.addStory,
        builder: (context, state) => const AddStoryScreen(),
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
        path: RoutePaths.rewards,
        name: RouteNames.rewards,
        builder: (context, state) => const RewardsScreen(),
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
        path: RoutePaths.adminSellers,
        name: RouteNames.adminSellers,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['sellers']!),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminFinancials,
        name: RouteNames.adminFinancials,
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(config: adminSectionConfigs['financials']!),
        ),
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
        builder: (context, state) => AdminShell(
          child: AdminSectionScreen(
            config: adminSectionConfigs['notificationAnalytics']!,
          ),
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
                path: RoutePaths.search,
                name: RouteNames.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.cart,
                name: RouteNames.cart,
                builder: (context, state) => const CartScreen(),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.orders,
                name: RouteNames.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.sellerCustomers,
                name: RouteNames.sellerCustomers,
                builder: (context, state) => const ExperienceSurfaceScreen(
                  surface: ExperienceSurface.customers,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.sellerMarketing,
                name: RouteNames.sellerMarketing,
                builder: (context, state) => const ExperienceSurfaceScreen(
                  surface: ExperienceSurface.marketing,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.sellerAnalytics,
                name: RouteNames.sellerAnalytics,
                builder: (context, state) => const ExperienceSurfaceScreen(
                  surface: ExperienceSurface.analytics,
                ),
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
  _ => OtpPurpose.phoneVerification,
};
