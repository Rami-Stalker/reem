import 'package:flutter/material.dart';

import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/user.dart';

enum ExperienceRole { buyer, seller, admin }

extension ExperienceRoleX on ExperienceRole {
  String get key => switch (this) {
    ExperienceRole.buyer => 'buyer',
    ExperienceRole.seller => 'seller',
    ExperienceRole.admin => 'admin',
  };

  String get label => switch (this) {
    ExperienceRole.buyer => 'Buyer',
    ExperienceRole.seller => 'Seller',
    ExperienceRole.admin => 'Admin',
  };

  static ExperienceRole fromUserRole(UserRole? role) => switch (role) {
    UserRole.seller => ExperienceRole.seller,
    UserRole.operationsAdmin ||
    UserRole.supportAdmin ||
    UserRole.financeAdmin ||
    UserRole.contentModerator ||
    UserRole.admin ||
    UserRole.superAdmin ||
    UserRole.support => ExperienceRole.admin,
    _ => ExperienceRole.buyer,
  };
}

enum ExperienceSurface {
  home,
  search,
  cart,
  rooms,
  closet,
  activity,
  profile,
  dashboard,
  products,
  orders,
  customers,
  analytics,
  users,
  sellers,
  finance,
  reports,
  moderation,
  settings,
}

enum ExperienceFeature {
  personalizedDiscovery,
  socialCommerce,
  cartCheckout,
  loyaltyRewards,
  sellerOperations,
  inventoryManagement,
  sellerAnalytics,
  marketingTools,
  adminGovernance,
  moderation,
  financialControls,
  auditControls,
}

class RoleVisualIdentity {
  const RoleVisualIdentity({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient,
    required this.icon,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Gradient gradient;
  final IconData icon;
}

class RoleNavigationItem {
  const RoleNavigationItem({
    required this.surface,
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    this.permission,
    this.feature,
  });

  final ExperienceSurface surface;
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String? permission;
  final ExperienceFeature? feature;
}

class RoleAction {
  const RoleAction({
    required this.id,
    required this.label,
    required this.path,
    required this.icon,
    this.permission,
    this.feature,
  });

  final String id;
  final String label;
  final String path;
  final IconData icon;
  final String? permission;
  final ExperienceFeature? feature;
}

class RoleDataSource {
  const RoleDataSource({
    required this.id,
    required this.label,
    required this.endpoint,
    required this.purpose,
    required this.freshness,
    this.permission,
    this.feature,
  });

  final String id;
  final String label;
  final String endpoint;
  final String purpose;
  final String freshness;
  final String? permission;
  final ExperienceFeature? feature;
}

class RoleMenuGroup {
  const RoleMenuGroup({
    required this.id,
    required this.label,
    required this.actions,
    this.permission,
    this.feature,
  });

  final String id;
  final String label;
  final List<RoleAction> actions;
  final String? permission;
  final ExperienceFeature? feature;
}

class RoleSurfaceSection {
  const RoleSurfaceSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.path,
    this.permission,
    this.feature,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String? path;
  final String? permission;
  final ExperienceFeature? feature;
}

class AppRoleExperience {
  const AppRoleExperience({
    required this.role,
    required this.title,
    required this.tagline,
    required this.defaultPath,
    required this.profilePath,
    required this.visualIdentity,
    required this.navigation,
    required this.quickActions,
    required this.homeSections,
    required this.profileSections,
    required this.dashboardSections,
    required this.dataSources,
    required this.menuGroups,
    required this.featureFlags,
    required this.permissions,
    required this.analyticsContext,
  });

  final ExperienceRole role;
  final String title;
  final String tagline;
  final String defaultPath;
  final String profilePath;
  final RoleVisualIdentity visualIdentity;
  final List<RoleNavigationItem> navigation;
  final List<RoleAction> quickActions;
  final List<RoleSurfaceSection> homeSections;
  final List<RoleSurfaceSection> profileSections;
  final List<RoleSurfaceSection> dashboardSections;
  final List<RoleDataSource> dataSources;
  final List<RoleMenuGroup> menuGroups;
  final Set<ExperienceFeature> featureFlags;
  final Set<String> permissions;
  final Map<String, String> analyticsContext;

  bool hasFeature(ExperienceFeature feature) => featureFlags.contains(feature);

  bool can(String permission) =>
      permissions.contains('*') || permissions.contains(permission);

  bool allows({String? permission, ExperienceFeature? feature}) {
    final hasPermission = permission == null || can(permission);
    final hasEnabledFeature = feature == null || hasFeature(feature);
    return hasPermission && hasEnabledFeature;
  }

  Iterable<RoleNavigationItem> get visibleNavigation => navigation.where(
    (item) => allows(permission: item.permission, feature: item.feature),
  );

  Iterable<RoleAction> get visibleQuickActions => quickActions.where(
    (item) => allows(permission: item.permission, feature: item.feature),
  );

  Iterable<RoleDataSource> get visibleDataSources => dataSources.where(
    (item) => allows(permission: item.permission, feature: item.feature),
  );

  Iterable<RoleMenuGroup> get visibleMenuGroups => menuGroups
      .where(
        (group) => allows(permission: group.permission, feature: group.feature),
      )
      .map(
        (group) => RoleMenuGroup(
          id: group.id,
          label: group.label,
          actions: group.actions
              .where(
                (action) => allows(
                  permission: action.permission,
                  feature: action.feature,
                ),
              )
              .toList(growable: false),
          permission: group.permission,
          feature: group.feature,
        ),
      )
      .where((group) => group.actions.isNotEmpty);

  RoleNavigationItem? navigationForPath(String path) {
    for (final item in navigation) {
      if (item.path == path || path.startsWith('${item.path}/')) return item;
    }
    return null;
  }

  Iterable<RoleSurfaceSection> sectionsFor(ExperienceSurface surface) {
    return switch (surface) {
      ExperienceSurface.home => homeSections,
      ExperienceSurface.profile => profileSections,
      ExperienceSurface.dashboard => dashboardSections,
      ExperienceSurface.activity => _buyerActivitySections,
      ExperienceSurface.analytics =>
        role == ExperienceRole.seller
            ? _sellerAnalyticsSections
            : dashboardSections,
      ExperienceSurface.settings => profileSections,
      _ => dashboardSections,
    }.where(
      (section) =>
          allows(permission: section.permission, feature: section.feature),
    );
  }

  static AppRoleExperience forUserRole(UserRole? role) {
    return switch (ExperienceRoleX.fromUserRole(role)) {
      ExperienceRole.seller => seller,
      ExperienceRole.admin => admin,
      ExperienceRole.buyer => buyer,
    };
  }

  static const buyer = AppRoleExperience(
    role: ExperienceRole.buyer,
    title: 'Ohara',
    tagline: 'A soft luxury boutique shaped around your taste.',
    defaultPath: RoutePaths.home,
    profilePath: RoutePaths.profile,
    visualIdentity: RoleVisualIdentity(
      primary: Color(0xFFC6386F),
      secondary: Color(0xFF533447),
      accent: Color(0xFFEACB8D),
      gradient: LinearGradient(
        colors: [Color(0xFFEF6C9B), Color(0xFFC84778), Color(0xFFEACB8D)],
      ),
      icon: Icons.favorite_rounded,
    ),
    navigation: [
      RoleNavigationItem(
        surface: ExperienceSurface.home,
        label: 'Home',
        path: RoutePaths.home,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        feature: ExperienceFeature.personalizedDiscovery,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.search,
        label: 'Discover',
        path: RoutePaths.search,
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        feature: ExperienceFeature.personalizedDiscovery,
      ),
      // The closet holds the third tab, and Rooms and Activity left the bar
      // to make room for it and for the create button the shell draws in the
      // middle. The closet is the one place that answers the question every
      // other screen now asks — does this go with what she owns — and it is
      // where Rooms is reached from: a room is a piece she is still deciding
      // on, one step before it is hers. Activity's links all live on Me.
      RoleNavigationItem(
        surface: ExperienceSurface.closet,
        label: 'Closet',
        path: RoutePaths.closet,
        icon: Icons.checkroom_outlined,
        selectedIcon: Icons.checkroom_rounded,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.profile,
        label: 'Me',
        path: RoutePaths.profile,
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ],
    quickActions: [
      // The stylist leads the buyer's quick actions: it is the only surface
      // where she can describe a situation rather than name a product, and
      // burying it behind search would make it the feature nobody discovers.
      RoleAction(
        id: 'ai-stylist',
        label: 'Stylist',
        path: RoutePaths.stylist,
        icon: Icons.auto_awesome_rounded,
        feature: ExperienceFeature.personalizedDiscovery,
      ),
      // The closet sits beside the stylist rather than under Profile: "شو
      // بلبس اليوم؟" is a question she has every morning, and a wardrobe two
      // taps deep is a wardrobe she keeps for a week and then forgets.
      RoleAction(
        id: 'closet',
        label: 'Closet',
        path: RoutePaths.closet,
        icon: Icons.checkroom_rounded,
        feature: ExperienceFeature.personalizedDiscovery,
      ),
      // The salons directory earns a quick action for the same reason the
      // closet does: booking a colour is an errand she starts from the home
      // screen, not something she goes looking for under a menu.
      RoleAction(
        id: 'salons',
        label: 'Salons & beauty',
        path: RoutePaths.salons,
        icon: Icons.content_cut_rounded,
        feature: ExperienceFeature.personalizedDiscovery,
      ),
      RoleAction(
        id: 'scan-search',
        label: 'Search',
        path: RoutePaths.search,
        icon: Icons.search_rounded,
        feature: ExperienceFeature.personalizedDiscovery,
      ),
      RoleAction(
        id: 'rooms',
        label: 'Rooms',
        path: RoutePaths.rooms,
        icon: Icons.meeting_room_rounded,
        feature: ExperienceFeature.cartCheckout,
      ),
      // The community, reels and the composer are quick actions rather than
      // tabs. The client specified five bottom icons, and a sixth would be a
      // stated requirement traded away for a shortcut.
      RoleAction(
        id: 'community',
        label: 'Community',
        path: RoutePaths.socialFeed,
        icon: Icons.auto_awesome_motion_rounded,
        feature: ExperienceFeature.socialCommerce,
      ),
      RoleAction(
        id: 'reels',
        label: 'Reels',
        path: RoutePaths.reels,
        icon: Icons.movie_creation_rounded,
        feature: ExperienceFeature.socialCommerce,
      ),
      RoleAction(
        id: 'compose',
        label: 'Post',
        path: RoutePaths.compose,
        icon: Icons.add_box_rounded,
        feature: ExperienceFeature.socialCommerce,
      ),
    ],
    homeSections: _buyerHomeSections,
    profileSections: _buyerProfileSections,
    dashboardSections: _buyerHomeSections,
    dataSources: _buyerDataSources,
    menuGroups: _buyerMenuGroups,
    featureFlags: {
      ExperienceFeature.personalizedDiscovery,
      ExperienceFeature.socialCommerce,
      ExperienceFeature.cartCheckout,
      ExperienceFeature.loyaltyRewards,
    },
    permissions: {
      'browse:read',
      'cart:write',
      'order:read',
      'profile:write',
      // She publishes now, not only shops. Presentation only — the server
      // judges every request again.
      'content:author',
      'content:interact',
    },
    analyticsContext: {
      'experience': 'buyer',
      'north_star': 'personalized_discovery',
    },
  );

  static const seller = AppRoleExperience(
    role: ExperienceRole.seller,
    title: 'Ohara Seller',
    tagline: 'Inventory, orders, customers, and growth in one fast workspace.',
    defaultPath: RoutePaths.sellerDashboard,
    profilePath: RoutePaths.sellerStore,
    visualIdentity: RoleVisualIdentity(
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF0F766E),
      accent: Color(0xFFD97706),
      gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF2563EB)]),
      icon: Icons.storefront_rounded,
    ),
    navigation: [
      RoleNavigationItem(
        surface: ExperienceSurface.dashboard,
        label: 'Dashboard',
        path: RoutePaths.sellerDashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        permission: 'seller:dashboard',
        feature: ExperienceFeature.sellerOperations,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.products,
        label: 'Products',
        path: RoutePaths.myProducts,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        permission: 'product:manage',
        feature: ExperienceFeature.inventoryManagement,
      ),
      // Her queue, not the customer's receipts. This entry pointed at
      // `/orders` — the buyer's purchase history — so the seller's Orders tab
      // opened a screen belonging to someone else entirely.
      RoleNavigationItem(
        surface: ExperienceSurface.orders,
        label: 'Orders',
        path: RoutePaths.sellerOrders,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        permission: 'order:manage',
        feature: ExperienceFeature.sellerOperations,
      ),
      // Customers and Marketing used to sit here. Both were card directories
      // over screens that did not exist, and half their cards led nowhere at
      // all — five tabs, two of them scenery. The work behind them is real and
      // lives where it belongs: conversations under Chats, content under the
      // composer, both reachable from her profile menu.
      RoleNavigationItem(
        surface: ExperienceSurface.analytics,
        label: 'Analytics',
        path: RoutePaths.sellerAnalytics,
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        feature: ExperienceFeature.sellerAnalytics,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.profile,
        label: 'Profile',
        path: RoutePaths.sellerStore,
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts_rounded,
      ),
    ],
    quickActions: [
      RoleAction(
        id: 'new-product',
        label: 'New product',
        path: RoutePaths.productForm,
        icon: Icons.add_business_rounded,
        permission: 'product:manage',
        feature: ExperienceFeature.inventoryManagement,
      ),
      // One composer for everybody. `/add-post` was seller-only, demanded a
      // product, and had no media picker at all — a post borrowed the
      // product's photographs.
      RoleAction(
        id: 'campaign',
        label: 'New post',
        path: RoutePaths.compose,
        icon: Icons.campaign_rounded,
        permission: 'content:author',
        feature: ExperienceFeature.marketingTools,
      ),
      RoleAction(
        id: 'content-studio',
        label: 'Content',
        path: RoutePaths.contentStudio,
        icon: Icons.insights_rounded,
        permission: 'analytics:read',
        feature: ExperienceFeature.marketingTools,
      ),
    ],
    homeSections: _sellerDashboardSections,
    profileSections: _sellerProfileSections,
    dashboardSections: _sellerDashboardSections,
    dataSources: _sellerDataSources,
    menuGroups: _sellerMenuGroups,
    featureFlags: {
      ExperienceFeature.sellerOperations,
      ExperienceFeature.inventoryManagement,
      ExperienceFeature.sellerAnalytics,
      ExperienceFeature.marketingTools,
    },
    permissions: {
      'seller:dashboard',
      'product:manage',
      'post:manage',
      'story:manage',
      // The content platform's own two. Presentation only — the server judges
      // every request again, and this list just stops a nav item advertising
      // a screen that would 403.
      'content:author',
      'content:interact',
      'order:manage',
      'analytics:read',
      // Mirrors `role-permissions.ts`: a SELLER may run a salon. Presentation
      // only, as with the rest of this list.
      'salon:manage',
    },
    analyticsContext: {
      'experience': 'seller',
      'north_star': 'seller_revenue_growth',
    },
  );

  static const admin = AppRoleExperience(
    role: ExperienceRole.admin,
    title: 'Ohara Admin',
    tagline: 'Enterprise control, governance, analytics, and operating health.',
    defaultPath: RoutePaths.admin,
    profilePath: RoutePaths.adminSystemSettings,
    visualIdentity: RoleVisualIdentity(
      primary: Color(0xFF3156D4),
      secondary: Color(0xFF0B1220),
      accent: Color(0xFFB91C1C),
      gradient: LinearGradient(colors: [Color(0xFF0B1220), Color(0xFF3156D4)]),
      icon: Icons.admin_panel_settings_rounded,
    ),
    // Every destination names the permission the API demands to open it, and
    // the shell hides the ones this operator does not hold. Several entries
    // used to carry no permission at all — finance, moderation and reports —
    // so a support agent was shown the finance console and handed a 403 for
    // walking into it. A menu that offers work the person cannot do is worse
    // than a shorter menu.
    navigation: [
      RoleNavigationItem(
        surface: ExperienceSurface.dashboard,
        label: 'Dashboard',
        path: RoutePaths.admin,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        permission: 'admin:dashboard',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.users,
        label: 'Users',
        path: RoutePaths.adminUsers,
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
        permission: 'user:manage',
        feature: ExperienceFeature.adminGovernance,
      ),
      // «توثيق الحسابات» — any account's claim on the badge, beside the
      // seller applications rather than inside them: the two are reviewed
      // against different evidence and answer different questions.
      RoleNavigationItem(
        surface: ExperienceSurface.users,
        label: 'Account verification',
        path: RoutePaths.adminAccountVerifications,
        icon: Icons.verified_user_outlined,
        selectedIcon: Icons.verified_user_rounded,
        permission: 'user:manage',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.sellers,
        label: 'Seller applications',
        path: RoutePaths.adminSellerApplications,
        icon: Icons.assignment_ind_outlined,
        selectedIcon: Icons.assignment_ind_rounded,
        permission: 'seller_verification:review',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.sellers,
        label: 'Sellers',
        path: RoutePaths.adminSellers,
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront_rounded,
        permission: 'seller_verification:review',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.products,
        label: 'Products',
        path: RoutePaths.adminProducts,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        permission: 'product:manage',
        feature: ExperienceFeature.moderation,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.orders,
        label: 'Orders',
        path: RoutePaths.adminOrders,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        permission: 'order:read',
        feature: ExperienceFeature.financialControls,
      ),
      // Q63 — the delivery companies that carry the parcels. Behind
      // `order:manage` rather than `order:read`: this screen turns a carrier on
      // and off for the whole platform, which is not a reading job.
      RoleNavigationItem(
        surface: ExperienceSurface.orders,
        label: 'Delivery',
        path: RoutePaths.adminDelivery,
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping_rounded,
        permission: 'order:manage',
        feature: ExperienceFeature.financialControls,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.customers,
        label: 'Support',
        path: RoutePaths.adminSupport,
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent_rounded,
        permission: 'support:read',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.moderation,
        label: 'Moderation',
        path: RoutePaths.adminModeration,
        icon: Icons.gavel_outlined,
        selectedIcon: Icons.gavel_rounded,
        permission: 'content:moderate',
        feature: ExperienceFeature.moderation,
      ),
      // The social platform's own queue, beside the generic moderation cases.
      // Same permission — it is the same job — but its own screen, because a
      // takedown needs a thumbnail and a mandatory reason.
      RoleNavigationItem(
        surface: ExperienceSurface.moderation,
        label: 'Content',
        path: RoutePaths.adminContent,
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library_rounded,
        permission: 'content:moderate',
        feature: ExperienceFeature.moderation,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.reports,
        label: 'Reports',
        path: RoutePaths.adminReports,
        icon: Icons.assessment_outlined,
        selectedIcon: Icons.assessment_rounded,
        permission: 'support:read',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.finance,
        label: 'Finance',
        path: RoutePaths.adminFinancials,
        icon: Icons.account_balance_outlined,
        selectedIcon: Icons.account_balance_rounded,
        permission: 'finance:read',
        feature: ExperienceFeature.financialControls,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.finance,
        label: 'Commissions',
        path: RoutePaths.adminCommissions,
        icon: Icons.percent_outlined,
        selectedIcon: Icons.percent_rounded,
        permission: 'finance:read',
        feature: ExperienceFeature.financialControls,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.analytics,
        label: 'Analytics',
        path: RoutePaths.adminAnalytics,
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        permission: 'analytics:read',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.analytics,
        label: 'Market intelligence',
        path: RoutePaths.adminTrends,
        icon: Icons.auto_graph_outlined,
        selectedIcon: Icons.auto_graph_rounded,
        permission: 'analytics:read',
        feature: ExperienceFeature.adminGovernance,
      ),
      // Ohara Value beside it, for the same reason: both are scored engines
      // with a policy behind them, and both are operated rather than
      // configured.
      RoleNavigationItem(
        surface: ExperienceSurface.analytics,
        label: 'Ohara Value',
        path: RoutePaths.adminValue,
        icon: Icons.workspace_premium_outlined,
        selectedIcon: Icons.workspace_premium_rounded,
        permission: 'analytics:read',
        feature: ExperienceFeature.adminGovernance,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.settings,
        label: 'Audit logs',
        path: RoutePaths.adminAuditLogs,
        icon: Icons.manage_search_outlined,
        selectedIcon: Icons.manage_search_rounded,
        permission: 'audit:read',
        feature: ExperienceFeature.auditControls,
      ),
      // The terms, privacy, returns, commissions, disputes, liability and
      // content policies. Behind `policy:manage` — its own permission, held by
      // the owner and operations and nobody else: publishing a version of the
      // terms of use changes the contract with every account, which is not the
      // same job as moderating a caption.
      RoleNavigationItem(
        surface: ExperienceSurface.settings,
        label: 'Policies',
        path: RoutePaths.adminPolicies,
        icon: Icons.policy_outlined,
        selectedIcon: Icons.policy_rounded,
        permission: 'policy:manage',
        feature: ExperienceFeature.auditControls,
      ),
      RoleNavigationItem(
        surface: ExperienceSurface.settings,
        label: 'Settings',
        path: RoutePaths.adminSystemSettings,
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune_rounded,
        permission: 'authorization:manage',
        feature: ExperienceFeature.auditControls,
      ),
    ],
    quickActions: [
      RoleAction(
        id: 'moderation',
        label: 'Moderation',
        path: RoutePaths.adminModeration,
        icon: Icons.gavel_rounded,
        feature: ExperienceFeature.moderation,
      ),
      RoleAction(
        id: 'reports',
        label: 'Reports',
        path: RoutePaths.adminReports,
        icon: Icons.assessment_rounded,
        feature: ExperienceFeature.adminGovernance,
      ),
    ],
    homeSections: _adminDashboardSections,
    profileSections: _adminProfileSections,
    dashboardSections: _adminDashboardSections,
    dataSources: _adminDataSources,
    menuGroups: _adminMenuGroups,
    featureFlags: {
      ExperienceFeature.adminGovernance,
      ExperienceFeature.moderation,
      ExperienceFeature.financialControls,
      ExperienceFeature.auditControls,
    },
    permissions: {'*'},
    analyticsContext: {'experience': 'admin', 'north_star': 'platform_health'},
  );
}

const _buyerDataSources = [
  RoleDataSource(
    id: 'personalized-feed',
    label: 'Personalized discovery feed',
    endpoint: '/discovery/feed',
    purpose:
        'Recommendations, trending products, featured sellers, stories, videos, and continue browsing.',
    freshness: 'near_real_time',
    feature: ExperienceFeature.personalizedDiscovery,
  ),
  RoleDataSource(
    id: 'cart-checkout',
    label: 'Cart and checkout state',
    endpoint: '/cart',
    purpose: 'Cart items, checkout readiness, coupons, and order conversion.',
    freshness: 'real_time',
    permission: 'cart:write',
    feature: ExperienceFeature.cartCheckout,
  ),
  RoleDataSource(
    id: 'loyalty-rewards',
    label: 'Loyalty and rewards',
    endpoint: '/rewards/me',
    purpose: 'Rewards balance, referral status, coupons, and loyalty prompts.',
    freshness: 'session',
    feature: ExperienceFeature.loyaltyRewards,
  ),
  RoleDataSource(
    id: 'profile-overview',
    label: 'Buyer profile overview',
    endpoint: '/profile/overview',
    purpose:
        'Orders, wishlist, addresses, payments, preferences, and account settings.',
    freshness: 'session',
    permission: 'profile:write',
  ),
];

const _buyerMenuGroups = [
  RoleMenuGroup(
    id: 'shopping',
    label: 'Shopping',
    actions: [
      // Above orders and wishlist on purpose. Both of those are records of
      // shopping; the closet is what the shopping was for, and it is the only
      // one of the three she has a reason to open on a day she is not buying
      // anything.
      RoleAction(
        id: 'rooms',
        label: 'My Rooms',
        path: RoutePaths.rooms,
        icon: Icons.meeting_room_rounded,
      ),
      RoleAction(
        id: 'closet',
        label: 'My Closet',
        path: RoutePaths.closet,
        icon: Icons.checkroom_rounded,
      ),
      // Phase four's shopper surfaces, under the closet because that is what
      // they are about: assembled looks, and the life of a piece after it is
      // delivered. The resale market is reached from the wardrobe rather than
      // listed here, so a second-hand shelf never sits beside the catalogue.
      RoleAction(
        id: 'market-bundles',
        label: 'Ready looks',
        path: RoutePaths.marketBundles,
        icon: Icons.auto_awesome_motion_rounded,
      ),
      RoleAction(
        id: 'market-wardrobe',
        label: 'Wardrobe care',
        path: RoutePaths.marketWardrobe,
        icon: Icons.spa_rounded,
      ),
      // «الصالونات والجمال». It sits in Shopping rather than in a group of
      // its own because that is what it is to her — another thing she buys on
      // Ohara — and a section with one entry reads like an afterthought.
      RoleAction(
        id: 'salons',
        label: 'Salons & beauty',
        path: RoutePaths.salons,
        icon: Icons.content_cut_rounded,
      ),
      // Directly under it, because a booking is found by looking for the
      // thing that made it.
      RoleAction(
        id: 'appointments',
        label: 'My appointments',
        path: RoutePaths.appointments,
        icon: Icons.event_available_rounded,
      ),
      // «مناسباتي» beside her bookings: the salon is most often booked for
      // one of these days, and the two are planned together.
      RoleAction(
        id: 'occasions',
        label: 'My occasions',
        path: RoutePaths.occasions,
        icon: Icons.celebration_rounded,
      ),
      RoleAction(
        id: 'orders',
        label: 'Orders',
        path: RoutePaths.orders,
        icon: Icons.receipt_long_rounded,
      ),
      RoleAction(
        id: 'wishlist',
        label: 'Wishlist',
        path: RoutePaths.favorites,
        icon: Icons.favorite_rounded,
      ),
      RoleAction(
        id: 'cart',
        label: 'Cart',
        path: RoutePaths.cart,
        icon: Icons.shopping_bag_rounded,
        permission: 'cart:write',
      ),
    ],
  ),
  RoleMenuGroup(
    id: 'standing',
    // Renamed from "Rewards": what she has here is a standing, and the things
    // under it are what it opens. "Rewards" is the vocabulary of a points
    // programme and it framed the whole group as a balance to be spent.
    label: 'Standing',
    feature: ExperienceFeature.loyaltyRewards,
    actions: [
      // Ohara Value leads. It is the thing that describes her; the two below are
      // instruments — credit she has accrued and codes she has been given.
      RoleAction(
        id: 'value',
        label: 'My standing',
        path: RoutePaths.value,
        icon: Icons.workspace_premium_rounded,
      ),
      // Missions sit under standing rather than under shopping, because what
      // they ask for earns standing through the same evidence everything else
      // does — and because they are emphatically not a shopping activity.
      RoleAction(
        id: 'market-missions',
        label: 'Worth doing',
        path: RoutePaths.marketMissions,
        icon: Icons.checklist_rounded,
      ),
      RoleAction(
        id: 'rewards',
        // Demoted to what it always was: Q43's cashback credit, which is money
        // rather than status. Naming it plainly is the point of the change.
        label: 'Credit & cashback',
        path: RoutePaths.rewards,
        icon: Icons.savings_rounded,
      ),
      RoleAction(
        id: 'coupons',
        label: 'Coupons',
        path: RoutePaths.coupons,
        icon: Icons.confirmation_num_rounded,
      ),
    ],
  ),
  RoleMenuGroup(
    id: 'account',
    label: 'Account',
    actions: [
      RoleAction(
        id: 'addresses',
        label: 'Addresses',
        path: RoutePaths.addresses,
        icon: Icons.location_on_rounded,
      ),
      RoleAction(
        id: 'payments',
        label: 'Payment methods',
        path: RoutePaths.paymentMethods,
        icon: Icons.credit_card_rounded,
      ),
      RoleAction(
        id: 'notifications',
        label: 'Notifications',
        path: RoutePaths.notifications,
        icon: Icons.notifications_rounded,
      ),
      RoleAction(
        id: 'settings',
        label: 'Settings',
        path: RoutePaths.settings,
        icon: Icons.settings_rounded,
      ),
    ],
  ),
];

const _sellerDataSources = [
  RoleDataSource(
    id: 'seller-performance',
    label: 'Seller performance dashboard',
    endpoint: '/analytics/seller/summary',
    purpose:
        'Revenue, conversion, customers, store health, and AI business insights.',
    freshness: 'near_real_time',
    permission: 'seller:dashboard',
    feature: ExperienceFeature.sellerOperations,
  ),
  RoleDataSource(
    id: 'seller-products',
    label: 'Product and inventory operations',
    endpoint: '/seller/products',
    purpose:
        'Catalog management, product performance, stock health, and inventory alerts.',
    freshness: 'real_time',
    permission: 'product:manage',
    feature: ExperienceFeature.inventoryManagement,
  ),
  RoleDataSource(
    id: 'seller-orders',
    label: 'Seller orders',
    endpoint: '/orders',
    purpose:
        'Order queues, fulfillment status, customer issues, and pending actions.',
    freshness: 'real_time',
    permission: 'order:manage',
    feature: ExperienceFeature.sellerOperations,
  ),
  RoleDataSource(
    id: 'seller-growth',
    label: 'Growth and marketing insights',
    endpoint: '/analytics/seller/growth',
    purpose:
        'Campaign performance, growth opportunities, and customer cohort signals.',
    freshness: 'hourly',
    feature: ExperienceFeature.sellerAnalytics,
  ),
];

const _sellerMenuGroups = [
  RoleMenuGroup(
    id: 'operations',
    label: 'Operations',
    feature: ExperienceFeature.sellerOperations,
    actions: [
      RoleAction(
        id: 'orders',
        label: 'Orders',
        path: RoutePaths.sellerOrders,
        icon: Icons.receipt_long_rounded,
        permission: 'order:manage',
      ),
      RoleAction(
        id: 'returns',
        label: 'Returns',
        path: RoutePaths.sellerReturns,
        icon: Icons.assignment_return_rounded,
        permission: 'order:manage',
      ),
      RoleAction(
        id: 'customers',
        label: 'Conversations',
        path: RoutePaths.chats,
        icon: Icons.groups_rounded,
      ),
      RoleAction(
        id: 'analytics',
        label: 'Analytics',
        path: RoutePaths.sellerAnalytics,
        icon: Icons.insights_rounded,
        feature: ExperienceFeature.sellerAnalytics,
      ),
      // Analytics answers what happened; this answers what is about to.
      RoleAction(
        id: 'trends',
        label: 'Trend engine',
        path: RoutePaths.sellerTrends,
        icon: Icons.auto_graph_rounded,
        feature: ExperienceFeature.sellerAnalytics,
      ),
      // And this answers whether anybody is serving it. The trend engine reads
      // demand; the market layer reads demand against supply, which is the
      // question a seller deciding what to stock actually has.
      RoleAction(
        id: 'market',
        label: 'Market',
        path: RoutePaths.sellerMarket,
        icon: Icons.trending_up_rounded,
        feature: ExperienceFeature.sellerAnalytics,
      ),
    ],
  ),
  RoleMenuGroup(
    id: 'growth',
    label: 'Growth',
    actions: [
      RoleAction(
        id: 'new-product',
        label: 'New product',
        path: RoutePaths.productForm,
        icon: Icons.add_business_rounded,
        permission: 'product:manage',
        feature: ExperienceFeature.inventoryManagement,
      ),
      RoleAction(
        id: 'marketing',
        label: 'New post',
        path: RoutePaths.addPost,
        icon: Icons.campaign_rounded,
        permission: 'post:manage',
        feature: ExperienceFeature.marketingTools,
      ),
    ],
  ),
  RoleMenuGroup(
    id: 'store',
    label: 'Store',
    actions: [
      RoleAction(
        id: 'store-profile',
        label: 'Store profile',
        path: RoutePaths.sellerStore,
        icon: Icons.storefront_rounded,
      ),

      // «صالوني». Under Store rather than Operations because it is a second
      // storefront, not a second inbox — and it carries `salon:manage`, which
      // a seller holds, so an account that has never opened a salon still
      // sees it and lands on the invitation to open one.
      RoleAction(
        id: 'salon-workspace',
        label: 'My salon',
        path: RoutePaths.salonWorkspace,
        icon: Icons.content_cut_rounded,
        permission: 'salon:manage',
      ),
      RoleAction(
        id: 'verification',
        label: 'Verification',
        path: RoutePaths.sellerVerification,
        icon: Icons.verified_rounded,
      ),
      RoleAction(
        id: 'security',
        label: 'Security',
        path: RoutePaths.securitySettings,
        icon: Icons.shield_rounded,
      ),
    ],
  ),
];

const _adminDataSources = [
  RoleDataSource(
    id: 'platform-analytics',
    label: 'Platform analytics',
    endpoint: '/admin/analytics/platform',
    purpose: 'GMV, revenue, order volume, buyers, sellers, and growth health.',
    freshness: 'near_real_time',
    permission: 'admin:dashboard',
    feature: ExperienceFeature.adminGovernance,
  ),
  RoleDataSource(
    id: 'financial-controls',
    label: 'Financial overview',
    endpoint: '/admin/financials',
    purpose:
        'Platform revenue, commissions, payouts, refunds, and financial risk.',
    freshness: 'near_real_time',
    feature: ExperienceFeature.financialControls,
  ),
  RoleDataSource(
    id: 'moderation-risk',
    label: 'Moderation and risk queue',
    endpoint: '/admin/moderation',
    purpose:
        'Disputes, fraud alerts, product moderation, seller verification, and abuse signals.',
    freshness: 'real_time',
    feature: ExperienceFeature.moderation,
  ),
  RoleDataSource(
    id: 'audit-system-health',
    label: 'Audit and system health',
    endpoint: '/admin/audit-logs',
    purpose:
        'Audit trails, access changes, security controls, and operational health.',
    freshness: 'real_time',
    permission: 'audit:read',
    feature: ExperienceFeature.auditControls,
  ),
];

const _adminMenuGroups = [
  RoleMenuGroup(
    id: 'governance',
    label: 'Governance',
    feature: ExperienceFeature.adminGovernance,
    actions: [
      RoleAction(
        id: 'users',
        label: 'Users',
        path: RoutePaths.adminUsers,
        icon: Icons.people_rounded,
        permission: 'user:manage',
      ),
      RoleAction(
        id: 'sellers',
        label: 'Sellers',
        path: RoutePaths.adminSellers,
        icon: Icons.verified_user_rounded,
        permission: 'seller_verification:review',
      ),
      RoleAction(
        id: 'reports',
        label: 'Reports',
        path: RoutePaths.adminReports,
        icon: Icons.summarize_rounded,
      ),
    ],
  ),
  RoleMenuGroup(
    id: 'risk',
    label: 'Risk',
    feature: ExperienceFeature.moderation,
    actions: [
      RoleAction(
        id: 'moderation',
        label: 'Moderation',
        path: RoutePaths.adminModeration,
        icon: Icons.policy_rounded,
      ),
      RoleAction(
        id: 'products',
        label: 'Products',
        path: RoutePaths.adminProducts,
        icon: Icons.inventory_2_rounded,
        permission: 'product:manage',
      ),
      RoleAction(
        id: 'orders',
        label: 'Orders',
        path: RoutePaths.adminOrders,
        icon: Icons.receipt_long_rounded,
        permission: 'order:manage',
      ),
    ],
  ),
  RoleMenuGroup(
    id: 'control',
    label: 'Control',
    actions: [
      RoleAction(
        id: 'finance',
        label: 'Finance',
        path: RoutePaths.adminFinancials,
        icon: Icons.account_balance_wallet_rounded,
        feature: ExperienceFeature.financialControls,
      ),
      RoleAction(
        id: 'value',
        label: 'Ohara Value',
        path: RoutePaths.adminValue,
        icon: Icons.workspace_premium_rounded,
      ),
      RoleAction(
        id: 'audit',
        label: 'Audit logs',
        path: RoutePaths.adminAuditLogs,
        icon: Icons.fact_check_rounded,
        permission: 'audit:read',
        feature: ExperienceFeature.auditControls,
      ),
      RoleAction(
        id: 'settings',
        label: 'Settings',
        path: RoutePaths.adminSystemSettings,
        icon: Icons.admin_panel_settings_rounded,
        permission: 'audit:read',
      ),
    ],
  ),
];

const _buyerHomeSections = [
  RoleSurfaceSection(
    id: 'recommendations',
    title: 'Personalized recommendations',
    description:
        'AI-ranked products, sellers, stories, and short-form commerce.',
    icon: Icons.auto_awesome_rounded,
    feature: ExperienceFeature.personalizedDiscovery,
  ),
  RoleSurfaceSection(
    id: 'marketplace',
    title: 'Trending products and flash deals',
    description:
        'High-intent shopping rails for categories, deals, and new arrivals.',
    icon: Icons.local_fire_department_rounded,
    feature: ExperienceFeature.cartCheckout,
  ),
  RoleSurfaceSection(
    id: 'engagement',
    title: 'Stories, videos, and activity',
    description:
        'Social proof, creator-led discovery, notifications, and messages.',
    icon: Icons.play_circle_rounded,
    feature: ExperienceFeature.socialCommerce,
  ),
  RoleSurfaceSection(
    id: 'loyalty',
    title: 'Loyalty and rewards',
    description:
        'Points, rewards, coupons, referrals, and personalized incentives.',
    icon: Icons.card_giftcard_rounded,
    feature: ExperienceFeature.loyaltyRewards,
  ),
];

const _buyerProfileSections = [
  RoleSurfaceSection(
    id: 'orders',
    title: 'Orders',
    description: 'Order history, tracking, returns, and reorder actions.',
    icon: Icons.receipt_long_rounded,
    path: RoutePaths.orders,
  ),
  RoleSurfaceSection(
    id: 'wishlist',
    title: 'Wishlist',
    description: 'Saved products, sellers, posts, and shareable collections.',
    icon: Icons.favorite_rounded,
    path: RoutePaths.favorites,
  ),
  RoleSurfaceSection(
    id: 'wallet',
    title: 'Rewards, coupons, addresses, and payments',
    description: 'Everything needed for fast checkout and retention.',
    icon: Icons.account_balance_wallet_rounded,
    path: RoutePaths.rewards,
  ),
  RoleSurfaceSection(
    id: 'preferences',
    title: 'Preferences and account settings',
    description:
        'Notifications, personalization controls, privacy, and security.',
    icon: Icons.tune_rounded,
    path: RoutePaths.settings,
  ),
];

const _buyerActivitySections = [
  RoleSurfaceSection(
    id: 'notifications',
    title: 'Notifications',
    description:
        'Price drops, order updates, seller replies, rewards, and reminders.',
    icon: Icons.notifications_rounded,
    path: RoutePaths.notifications,
  ),
  RoleSurfaceSection(
    id: 'orders',
    title: 'Order activity',
    description:
        'Track purchases, delivery milestones, returns, and support events.',
    icon: Icons.local_shipping_rounded,
    path: RoutePaths.orders,
  ),
  RoleSurfaceSection(
    id: 'messages',
    title: 'Messages',
    description: 'Buyer-seller conversations and story shares.',
    icon: Icons.chat_bubble_rounded,
    path: RoutePaths.chats,
  ),
];

const _sellerDashboardSections = [
  RoleSurfaceSection(
    id: 'revenue',
    title: 'Revenue summary',
    description:
        'Net sales, payout readiness, commission, fees, and growth trend.',
    icon: Icons.payments_rounded,
    feature: ExperienceFeature.sellerOperations,
  ),
  RoleSurfaceSection(
    id: 'operations',
    title: 'Orders and inventory',
    description:
        'Fulfilment workload, stock alerts, pending tasks, and SLA health.',
    icon: Icons.inventory_2_rounded,
    feature: ExperienceFeature.inventoryManagement,
  ),
  RoleSurfaceSection(
    id: 'growth',
    title: 'Conversion and customers',
    description:
        'Traffic, conversion, repeat buyers, reviews, and customer quality.',
    icon: Icons.trending_up_rounded,
    feature: ExperienceFeature.sellerAnalytics,
  ),
  RoleSurfaceSection(
    id: 'insights',
    title: 'AI business insights',
    description:
        'Pricing, merchandising, stock, and promotion recommendations.',
    icon: Icons.psychology_rounded,
    feature: ExperienceFeature.sellerAnalytics,
  ),
];

const _sellerProfileSections = [
  RoleSurfaceSection(
    id: 'business',
    title: 'Business information',
    description:
        'Store profile, verification, business identity, and public presence.',
    icon: Icons.store_mall_directory_rounded,
  ),
  RoleSurfaceSection(
    id: 'financials',
    title: 'Financial settings',
    description:
        'Payouts, commission rules, tax details, invoices, and bank data.',
    icon: Icons.account_balance_rounded,
  ),
  RoleSurfaceSection(
    id: 'shipping',
    title: 'Shipping settings',
    description:
        'Regions, fulfilment policies, processing time, and delivery rules.',
    icon: Icons.local_shipping_rounded,
  ),
  RoleSurfaceSection(
    id: 'team',
    title: 'Team management and security',
    description:
        'Staff roles, access control, MFA, sessions, and device trust.',
    icon: Icons.admin_panel_settings_rounded,
  ),
];

const _sellerAnalyticsSections = [
  RoleSurfaceSection(
    id: 'sales',
    title: 'Sales analytics',
    description:
        'Revenue, AOV, profit margin, order velocity, and payout trend.',
    icon: Icons.query_stats_rounded,
  ),
  RoleSurfaceSection(
    id: 'products',
    title: 'Product performance',
    description:
        'Top products, low performers, inventory risk, and conversion gaps.',
    icon: Icons.inventory_rounded,
  ),
  RoleSurfaceSection(
    id: 'customers',
    title: 'Customer metrics',
    description: 'Retention, repeat rate, lifetime value, and cohort health.',
    icon: Icons.people_alt_rounded,
  ),
];

const _adminDashboardSections = [
  RoleSurfaceSection(
    id: 'platform-revenue',
    title: 'Platform revenue and GMV',
    description:
        'Gross merchandise value, net revenue, commissions, and payouts.',
    icon: Icons.account_balance_rounded,
    feature: ExperienceFeature.financialControls,
  ),
  RoleSurfaceSection(
    id: 'market-health',
    title: 'Active buyers, sellers, and orders',
    description:
        'Demand, supply, growth, retention, and marketplace liquidity.',
    icon: Icons.analytics_rounded,
    feature: ExperienceFeature.adminGovernance,
  ),
  RoleSurfaceSection(
    id: 'risk',
    title: 'Disputes, moderation, and fraud alerts',
    description:
        'Operational queues, policy violations, abuse, and escalations.',
    icon: Icons.security_rounded,
    feature: ExperienceFeature.moderation,
  ),
  RoleSurfaceSection(
    id: 'system',
    title: 'System health and audit stream',
    description:
        'Service health, admin activity, access controls, and compliance.',
    icon: Icons.health_and_safety_rounded,
    feature: ExperienceFeature.auditControls,
  ),
];

const _adminProfileSections = [
  RoleSurfaceSection(
    id: 'administrator-settings',
    title: 'Administrator settings',
    description:
        'Personal admin profile, notification routing, and console defaults.',
    icon: Icons.admin_panel_settings_rounded,
    path: RoutePaths.adminSystemSettings,
  ),
  RoleSurfaceSection(
    id: 'security-controls',
    title: 'Security controls',
    description:
        'MFA, device trust, sessions, role assignment, and access review.',
    icon: Icons.lock_rounded,
    path: RoutePaths.securitySettings,
  ),
  RoleSurfaceSection(
    id: 'audit-logs',
    title: 'Audit logs',
    description:
        'Administrative actions, sensitive changes, and governance trail.',
    icon: Icons.manage_search_rounded,
    path: RoutePaths.adminAuditLogs,
  ),
];
