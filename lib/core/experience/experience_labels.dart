import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The Arabic the shell actually shows.
///
/// [RoleNavigationItem.label], [RoleAction.label] and [RoleMenuGroup.label]
/// stay English constants: they are part of a `const` role manifest that is
/// built long before a `BuildContext` exists, and they double as the names
/// analytics reports under. Reading them straight into the bottom bar is why
/// a shopper who switched the app to Arabic still got «Home / Search / Cart /
/// Activity / Profile» along the bottom of every screen.
///
/// So the manifest keeps its identifiers and the copy is resolved here, at
/// display time, from the stable key each entry already carries — a route for
/// a destination, an id for an action or a group. This mirrors
/// `AdminSectionTitle`, which solved the same split for the console.
///
/// An entry added to the manifest without a translation still renders, in its
/// English name, rather than throwing at whoever is holding the phone.
extension RoleNavigationItemLabel on RoleNavigationItem {
  String labelOf(AppLocalizations l10n) => switch (path) {
    RoutePaths.home => l10n.navHome,
    RoutePaths.search => l10n.navSearch,
    RoutePaths.cart => l10n.navCart,
    RoutePaths.activity => l10n.navActivity,
    RoutePaths.profile => l10n.navProfile,
    RoutePaths.sellerDashboard => l10n.navSellerDashboard,
    RoutePaths.myProducts => l10n.navSellerProducts,
    RoutePaths.sellerOrders => l10n.navSellerOrders,
    RoutePaths.sellerAnalytics => l10n.navSellerAnalytics,
    RoutePaths.sellerStore => l10n.navSellerStore,
    // The console's own destinations keep the console's own strings. The
    // admin shell used to carry this mapping privately; both reading it from
    // here is what stops the rail and the bottom bar naming the same screen
    // two different ways.
    RoutePaths.admin => l10n.adminDashboard,
    RoutePaths.adminUsers => l10n.adminUsers,
    RoutePaths.adminSellerApplications => l10n.adminSellerApplications,
    RoutePaths.adminSellers => l10n.adminSellerManagement,
    RoutePaths.adminProducts => l10n.adminProducts,
    RoutePaths.adminOrders => l10n.adminOrders,
    RoutePaths.adminSupport => l10n.adminSupportQueue,
    RoutePaths.adminModeration => l10n.adminModeration,
    RoutePaths.adminContent => l10n.adminContentTitle,
    RoutePaths.adminReports => l10n.adminReports,
    RoutePaths.adminFinancials => l10n.adminFinance,
    RoutePaths.adminCommissions => l10n.adminCommissionManagement,
    RoutePaths.adminAnalytics => l10n.adminAnalytics,
    RoutePaths.adminTrends => l10n.trendsAdminTitle,
    RoutePaths.adminDelivery => l10n.adminDelivery,
    RoutePaths.adminPolicies => l10n.adminPolicies,
    RoutePaths.adminAuditLogs => l10n.adminAuditLogs,
    RoutePaths.adminSystemSettings => l10n.adminSystemSettings,
    _ => label,
  };
}

/// Quick actions and menu entries, keyed by the id the manifest gives them.
///
/// Ids repeat across roles on purpose — the seller's `orders` and the buyer's
/// `orders` are the same word in both languages — so one arm serves both.
extension RoleActionLabel on RoleAction {
  String labelOf(AppLocalizations l10n) => switch (id) {
    'ai-stylist' => l10n.actionStylist,
    'scan-search' => l10n.actionSearch,
    'cart' => l10n.actionCart,
    'new-product' => l10n.actionNewProduct,
    'campaign' || 'marketing' => l10n.actionNewPost,
    'moderation' => l10n.actionModeration,
    'reports' => l10n.actionReports,
    'orders' => l10n.actionOrders,
    'wishlist' => l10n.actionWishlist,
    'rewards' => l10n.actionRewards,
    'coupons' => l10n.actionCoupons,
    'addresses' => l10n.actionAddresses,
    'payments' => l10n.actionPayments,
    'notifications' => l10n.actionNotifications,
    'settings' => l10n.actionSettings,
    'returns' => l10n.actionReturns,
    'customers' => l10n.actionConversations,
    'analytics' => l10n.actionAnalytics,
    'trends' => l10n.actionTrends,
    'store-profile' => l10n.actionStoreProfile,
    'verification' => l10n.actionVerification,
    'security' => l10n.actionSecurity,
    'users' => l10n.actionUsers,
    'sellers' => l10n.actionSellers,
    'products' => l10n.actionProducts,
    'finance' => l10n.actionFinance,
    'audit' => l10n.actionAudit,
    _ => label,
  };
}

/// The cards on a surface built from the role manifest.
///
/// [RoleSurfaceSection] was the one entry in the manifest that never got this
/// treatment, and the Activity tab is the one place a shopper sees them — so
/// one of her five tabs was three cards reading «Notifications / Order
/// activity / Messages» in English, in an Arabic-first app, no matter what she
/// had set the language to.
extension RoleSurfaceSectionLabel on RoleSurfaceSection {
  String titleOf(AppLocalizations l10n) => switch (id) {
    'notifications' => l10n.notifications,
    'orders' => l10n.orders,
    'messages' => l10n.messages,
    _ => title,
  };

  String descriptionOf(AppLocalizations l10n) => switch (id) {
    'notifications' => l10n.activityNotificationsBlurb,
    'orders' => l10n.activityOrdersBlurb,
    'messages' => l10n.activityMessagesBlurb,
    _ => description,
  };
}

/// The headings over the profile and console menus.
extension RoleMenuGroupLabel on RoleMenuGroup {
  String labelOf(AppLocalizations l10n) => switch (id) {
    'shopping' => l10n.menuGroupShopping,
    'rewards' => l10n.menuGroupRewards,
    'account' => l10n.menuGroupAccount,
    'operations' => l10n.menuGroupOperations,
    'growth' => l10n.menuGroupGrowth,
    'store' => l10n.menuGroupStore,
    'governance' => l10n.menuGroupGovernance,
    'risk' => l10n.menuGroupRisk,
    'control' => l10n.menuGroupControl,
    _ => label,
  };
}
