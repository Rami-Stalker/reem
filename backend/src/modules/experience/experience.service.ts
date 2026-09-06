import { Injectable } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';

export type ExperienceRole = 'buyer' | 'seller' | 'admin';

export interface ExperienceNavItem {
  id: string;
  label: string;
  path: string;
  permission?: string;
  feature?: string;
}

export interface ExperienceSection {
  id: string;
  title: string;
  feature?: string;
  permission?: string;
}

export interface ExperienceAction {
  id: string;
  label: string;
  path: string;
  permission?: string;
  feature?: string;
}

export interface ExperienceDataSource {
  id: string;
  label: string;
  endpoint: string;
  purpose: string;
  freshness: 'real_time' | 'near_real_time' | 'hourly' | 'session';
  permission?: string;
  feature?: string;
}

export interface ExperienceMenuGroup {
  id: string;
  label: string;
  actions: ExperienceAction[];
  permission?: string;
  feature?: string;
}

export interface ExperienceConfig {
  role: ExperienceRole;
  title: string;
  default_route: string;
  profile_route: string;
  visual_identity: {
    primary: string;
    secondary: string;
    accent: string;
    tone: 'discovery' | 'business' | 'enterprise';
  };
  navigation: ExperienceNavItem[];
  quick_actions: ExperienceAction[];
  home_sections: ExperienceSection[];
  dashboard_widgets: ExperienceSection[];
  profile_sections: ExperienceSection[];
  data_sources: ExperienceDataSource[];
  menu_groups: ExperienceMenuGroup[];
  feature_flags: string[];
  permissions: string[];
  analytics_context: Record<string, string>;
}

type GateableExperienceItem = {
  permission?: string;
  feature?: string;
};

@Injectable()
export class ExperienceService {
  getForUser(user: AuthUser): ExperienceConfig {
    const role = this.roleFor(user.role);
    const config = experienceConfigs[role];
    const permissions = this.permissionsFor(user, config);
    const permissionSet = new Set(permissions);
    const featureSet = new Set(config.feature_flags);

    return {
      ...config,
      navigation: this.filterItems(config.navigation, permissionSet, featureSet),
      quick_actions: this.filterItems(
        config.quick_actions,
        permissionSet,
        featureSet,
      ),
      home_sections: this.filterItems(
        config.home_sections,
        permissionSet,
        featureSet,
      ),
      dashboard_widgets: this.filterItems(
        config.dashboard_widgets,
        permissionSet,
        featureSet,
      ),
      profile_sections: this.filterItems(
        config.profile_sections,
        permissionSet,
        featureSet,
      ),
      data_sources: this.filterItems(
        config.data_sources,
        permissionSet,
        featureSet,
      ),
      menu_groups: this.filterMenuGroups(config.menu_groups, permissionSet, featureSet),
      permissions,
    };
  }

  private roleFor(role: UserRole): ExperienceRole {
    switch (role) {
      case UserRole.SELLER:
        return 'seller';
      case UserRole.OPERATIONS_ADMIN:
      case UserRole.SUPPORT_ADMIN:
      case UserRole.FINANCE_ADMIN:
      case UserRole.CONTENT_MODERATOR:
      case UserRole.ADMIN:
      case UserRole.SUPER_ADMIN:
      case UserRole.SUPPORT:
        return 'admin';
      default:
        return 'buyer';
    }
  }

  private permissionsFor(
    user: AuthUser,
    config: ExperienceConfig,
  ): string[] {
    const permissions = new Set(config.permissions);
    for (const permission of user.permissions ?? []) {
      permissions.add(permission);
    }
    if (user.role === UserRole.SUPER_ADMIN) permissions.add('*');
    return [...permissions].sort();
  }

  private filterItems<T extends GateableExperienceItem>(
    items: T[],
    permissions: Set<string>,
    features: Set<string>,
  ): T[] {
    return items.filter((item) => this.isAllowed(item, permissions, features));
  }

  private filterMenuGroups(
    groups: ExperienceMenuGroup[],
    permissions: Set<string>,
    features: Set<string>,
  ): ExperienceMenuGroup[] {
    return groups
      .filter((group) => this.isAllowed(group, permissions, features))
      .map((group) => ({
        ...group,
        actions: this.filterItems(group.actions, permissions, features),
      }))
      .filter((group) => group.actions.length > 0);
  }

  private isAllowed(
    item: GateableExperienceItem,
    permissions: Set<string>,
    features: Set<string>,
  ): boolean {
    const hasPermission =
      !item.permission || permissions.has('*') || permissions.has(item.permission);
    const hasFeature = !item.feature || features.has(item.feature);
    return hasPermission && hasFeature;
  }
}

const buyerNav: ExperienceNavItem[] = [
  { id: 'home', label: 'Home', path: '/home', feature: 'personalized_discovery' },
  { id: 'search', label: 'Search', path: '/search', feature: 'personalized_discovery' },
  { id: 'cart', label: 'Cart', path: '/cart', feature: 'cart_checkout' },
  { id: 'activity', label: 'Activity', path: '/activity', feature: 'social_commerce' },
  { id: 'profile', label: 'Profile', path: '/profile' },
];

const sellerNav: ExperienceNavItem[] = [
  { id: 'dashboard', label: 'Dashboard', path: '/seller/dashboard', permission: 'seller:dashboard' },
  { id: 'products', label: 'Products', path: '/seller/products', permission: AppPermission.productManage },
  { id: 'orders', label: 'Orders', path: '/orders', permission: AppPermission.orderManage },
  { id: 'customers', label: 'Customers', path: '/seller/customers', feature: 'seller_operations' },
  { id: 'marketing', label: 'Marketing', path: '/seller/marketing', permission: AppPermission.postManage },
  { id: 'analytics', label: 'Analytics', path: '/seller/analytics', feature: 'seller_analytics' },
  { id: 'profile', label: 'Profile', path: '/seller/store' },
];

const adminNav: ExperienceNavItem[] = [
  { id: 'dashboard', label: 'Dashboard', path: '/admin', permission: 'admin:dashboard' },
  { id: 'users', label: 'Users', path: '/admin/users', permission: AppPermission.userManage },
  { id: 'sellers', label: 'Sellers', path: '/admin/sellers', permission: AppPermission.sellerVerificationReview },
  { id: 'products', label: 'Products', path: '/admin/products', permission: AppPermission.productManage },
  { id: 'orders', label: 'Orders', path: '/admin/orders', permission: AppPermission.orderManage },
  { id: 'finance', label: 'Finance', path: '/admin/financials', feature: 'financial_controls' },
  { id: 'reports', label: 'Reports', path: '/admin/reports', feature: 'admin_governance' },
  { id: 'moderation', label: 'Moderation', path: '/admin/moderation', feature: 'moderation' },
  { id: 'settings', label: 'Settings', path: '/admin/system-settings', permission: AppPermission.auditRead },
];

const experienceConfigs: Record<ExperienceRole, ExperienceConfig> = {
  buyer: {
    role: 'buyer',
    title: 'Reem',
    default_route: '/home',
    profile_route: '/profile',
    visual_identity: {
      primary: '#E84C88',
      secondary: '#7C4DFF',
      accent: '#FFB86B',
      tone: 'discovery',
    },
    navigation: buyerNav,
    quick_actions: [
      {
        id: 'search',
        label: 'Search',
        path: '/search',
        feature: 'personalized_discovery',
      },
      { id: 'cart', label: 'Cart', path: '/cart', feature: 'cart_checkout' },
    ],
    home_sections: [
      { id: 'recommendations', title: 'Personalized recommendations', feature: 'personalized_discovery' },
      { id: 'trending', title: 'Trending products and flash deals', feature: 'cart_checkout' },
      { id: 'stories', title: 'Stories and short videos', feature: 'social_commerce' },
      { id: 'loyalty', title: 'Loyalty and rewards', feature: 'loyalty_rewards' },
    ],
    dashboard_widgets: [],
    profile_sections: [
      { id: 'orders', title: 'Orders' },
      { id: 'wishlist', title: 'Wishlist' },
      { id: 'rewards', title: 'Rewards and coupons' },
      { id: 'settings', title: 'Preferences and account settings' },
    ],
    data_sources: [
      {
        id: 'personalized-feed',
        label: 'Personalized discovery feed',
        endpoint: '/discovery/feed',
        purpose: 'Recommendations, trending products, sellers, stories, videos, and continue browsing.',
        freshness: 'near_real_time',
        feature: 'personalized_discovery',
      },
      {
        id: 'cart-checkout',
        label: 'Cart and checkout state',
        endpoint: '/cart',
        purpose: 'Cart items, checkout readiness, coupons, and order conversion.',
        freshness: 'real_time',
        permission: 'cart:write',
        feature: 'cart_checkout',
      },
      {
        id: 'loyalty-rewards',
        label: 'Loyalty and rewards',
        endpoint: '/rewards/me',
        purpose: 'Rewards balance, referral status, coupons, and loyalty prompts.',
        freshness: 'session',
        feature: 'loyalty_rewards',
      },
      {
        id: 'profile-overview',
        label: 'Buyer profile overview',
        endpoint: '/profile/overview',
        purpose: 'Orders, wishlist, addresses, payments, preferences, and account settings.',
        freshness: 'session',
        permission: 'profile:write',
      },
    ],
    menu_groups: [
      {
        id: 'shopping',
        label: 'Shopping',
        actions: [
          { id: 'orders', label: 'Orders', path: '/orders' },
          { id: 'wishlist', label: 'Wishlist', path: '/favorites' },
          {
            id: 'cart',
            label: 'Cart',
            path: '/cart',
            permission: 'cart:write',
          },
        ],
      },
      {
        id: 'rewards',
        label: 'Rewards',
        feature: 'loyalty_rewards',
        actions: [
          { id: 'rewards', label: 'Rewards', path: '/rewards' },
          { id: 'coupons', label: 'Coupons', path: '/coupons' },
        ],
      },
      {
        id: 'account',
        label: 'Account',
        actions: [
          { id: 'addresses', label: 'Addresses', path: '/addresses' },
          { id: 'payments', label: 'Payment methods', path: '/payment-methods' },
          { id: 'notifications', label: 'Notifications', path: '/notifications' },
          { id: 'settings', label: 'Settings', path: '/settings' },
        ],
      },
    ],
    feature_flags: [
      'personalized_discovery',
      'social_commerce',
      'cart_checkout',
      'loyalty_rewards',
    ],
    permissions: ['browse:read', 'cart:write', 'order:read', 'profile:write'],
    analytics_context: {
      experience: 'buyer',
      north_star: 'personalized_discovery',
    },
  },
  seller: {
    role: 'seller',
    title: 'Reem Seller',
    default_route: '/seller/dashboard',
    profile_route: '/seller/store',
    visual_identity: {
      primary: '#146C94',
      secondary: '#19A7CE',
      accent: '#F4C430',
      tone: 'business',
    },
    navigation: sellerNav,
    quick_actions: [
      {
        id: 'new-product',
        label: 'New product',
        path: '/seller/products/form',
        permission: AppPermission.productManage,
        feature: 'inventory_management',
      },
      {
        id: 'campaign',
        label: 'Campaign',
        path: '/seller/marketing',
        permission: AppPermission.postManage,
        feature: 'marketing_tools',
      },
    ],
    home_sections: [],
    dashboard_widgets: [
      { id: 'revenue', title: 'Revenue summary', feature: 'seller_operations' },
      { id: 'orders', title: 'Orders overview', permission: AppPermission.orderManage },
      { id: 'inventory', title: 'Inventory alerts', permission: AppPermission.productManage },
      { id: 'insights', title: 'AI business insights', feature: 'seller_analytics' },
    ],
    profile_sections: [
      { id: 'business', title: 'Business information' },
      { id: 'financials', title: 'Financial settings' },
      { id: 'shipping', title: 'Shipping settings' },
      { id: 'team', title: 'Team management and security' },
    ],
    data_sources: [
      {
        id: 'seller-performance',
        label: 'Seller performance dashboard',
        endpoint: '/analytics/seller/summary',
        purpose: 'Revenue, conversion, customers, store health, and AI business insights.',
        freshness: 'near_real_time',
        permission: 'seller:dashboard',
        feature: 'seller_operations',
      },
      {
        id: 'seller-products',
        label: 'Product and inventory operations',
        endpoint: '/seller/products',
        purpose: 'Catalog management, product performance, stock health, and inventory alerts.',
        freshness: 'real_time',
        permission: AppPermission.productManage,
        feature: 'inventory_management',
      },
      {
        id: 'seller-orders',
        label: 'Seller orders',
        endpoint: '/orders',
        purpose: 'Order queues, fulfillment status, customer issues, and pending actions.',
        freshness: 'real_time',
        permission: AppPermission.orderManage,
        feature: 'seller_operations',
      },
      {
        id: 'seller-growth',
        label: 'Growth and marketing insights',
        endpoint: '/analytics/seller/growth',
        purpose: 'Campaign performance, growth opportunities, and customer cohort signals.',
        freshness: 'hourly',
        feature: 'seller_analytics',
      },
    ],
    menu_groups: [
      {
        id: 'operations',
        label: 'Operations',
        feature: 'seller_operations',
        actions: [
          {
            id: 'orders',
            label: 'Orders',
            path: '/orders',
            permission: AppPermission.orderManage,
          },
          { id: 'customers', label: 'Customers', path: '/seller/customers' },
          {
            id: 'analytics',
            label: 'Analytics',
            path: '/seller/analytics',
            feature: 'seller_analytics',
          },
        ],
      },
      {
        // Phase two of the commerce OS. Grouped on its own rather than folded
        // into Analytics because it answers a different question: analytics
        // says what happened, these say what to do about it.
        id: 'intelligence',
        label: 'Intelligence',
        actions: [
          {
            id: 'demand-radar',
            label: 'Demand radar',
            path: '/seller/radar',
            feature: 'seller_intelligence',
          },
          {
            id: 'product-intelligence',
            label: 'Product intelligence',
            path: '/seller/product-intelligence',
            feature: 'seller_intelligence',
          },
          {
            id: 'store-health',
            label: 'Store health',
            path: '/seller/health',
            feature: 'seller_intelligence',
          },
        ],
      },
      {
        id: 'growth',
        label: 'Growth',
        actions: [
          {
            id: 'new-product',
            label: 'New product',
            path: '/seller/products/form',
            permission: AppPermission.productManage,
            feature: 'inventory_management',
          },
          {
            id: 'marketing',
            label: 'Marketing',
            path: '/seller/marketing',
            permission: AppPermission.postManage,
            feature: 'marketing_tools',
          },
        ],
      },
      {
        id: 'store',
        label: 'Store',
        actions: [
          { id: 'store-profile', label: 'Store profile', path: '/seller/store' },
          { id: 'verification', label: 'Verification', path: '/seller-verification' },
          { id: 'security', label: 'Security', path: '/security' },
        ],
      },
    ],
    feature_flags: [
      'seller_operations',
      'seller_intelligence',
      'inventory_management',
      'seller_analytics',
      'marketing_tools',
    ],
    permissions: [
      'seller:dashboard',
      AppPermission.productManage,
      AppPermission.postManage,
      AppPermission.storyManage,
      AppPermission.orderManage,
      'analytics:read',
    ],
    analytics_context: {
      experience: 'seller',
      north_star: 'seller_revenue_growth',
    },
  },
  admin: {
    role: 'admin',
    title: 'Reem Admin',
    default_route: '/admin',
    profile_route: '/admin/system-settings',
    visual_identity: {
      primary: '#344054',
      secondary: '#175CD3',
      accent: '#D92D20',
      tone: 'enterprise',
    },
    navigation: adminNav,
    quick_actions: [
      {
        id: 'moderation',
        label: 'Moderation',
        path: '/admin/moderation',
        feature: 'moderation',
      },
      {
        id: 'reports',
        label: 'Reports',
        path: '/admin/reports',
        feature: 'admin_governance',
      },
    ],
    home_sections: [],
    dashboard_widgets: [
      { id: 'gmv', title: 'Platform revenue and GMV', feature: 'financial_controls' },
      { id: 'users', title: 'Active users, sellers, and buyers', feature: 'admin_governance' },
      { id: 'risk', title: 'Disputes, moderation, and fraud alerts', feature: 'moderation' },
      { id: 'system', title: 'System health and audit stream', permission: AppPermission.auditRead },
    ],
    profile_sections: [
      { id: 'administrator', title: 'Administrator settings' },
      { id: 'security', title: 'Security controls' },
      { id: 'audit', title: 'Audit logs', permission: AppPermission.auditRead },
      { id: 'access', title: 'Access management', permission: AppPermission.userManage },
    ],
    data_sources: [
      {
        id: 'platform-analytics',
        label: 'Platform analytics',
        endpoint: '/admin/analytics/platform',
        purpose: 'GMV, revenue, order volume, buyers, sellers, and growth health.',
        freshness: 'near_real_time',
        permission: 'admin:dashboard',
        feature: 'admin_governance',
      },
      {
        id: 'financial-controls',
        label: 'Financial overview',
        endpoint: '/admin/financials',
        purpose: 'Platform revenue, commissions, payouts, refunds, and financial risk.',
        freshness: 'near_real_time',
        feature: 'financial_controls',
      },
      {
        id: 'moderation-risk',
        label: 'Moderation and risk queue',
        endpoint: '/admin/moderation',
        purpose: 'Disputes, fraud alerts, product moderation, seller verification, and abuse signals.',
        freshness: 'real_time',
        feature: 'moderation',
      },
      {
        id: 'audit-system-health',
        label: 'Audit and system health',
        endpoint: '/admin/audit-logs',
        purpose: 'Audit trails, access changes, security controls, and operational health.',
        freshness: 'real_time',
        permission: AppPermission.auditRead,
        feature: 'audit_controls',
      },
    ],
    menu_groups: [
      {
        id: 'governance',
        label: 'Governance',
        feature: 'admin_governance',
        actions: [
          {
            id: 'users',
            label: 'Users',
            path: '/admin/users',
            permission: AppPermission.userManage,
          },
          {
            id: 'sellers',
            label: 'Sellers',
            path: '/admin/sellers',
            permission: AppPermission.sellerVerificationReview,
          },
          { id: 'reports', label: 'Reports', path: '/admin/reports' },
        ],
      },
      {
        id: 'risk',
        label: 'Risk',
        feature: 'moderation',
        actions: [
          { id: 'moderation', label: 'Moderation', path: '/admin/moderation' },
          {
            id: 'products',
            label: 'Products',
            path: '/admin/products',
            permission: AppPermission.productManage,
          },
          {
            id: 'orders',
            label: 'Orders',
            path: '/admin/orders',
            permission: AppPermission.orderManage,
          },
        ],
      },
      {
        id: 'control',
        label: 'Control',
        actions: [
          {
            id: 'finance',
            label: 'Finance',
            path: '/admin/financials',
            feature: 'financial_controls',
          },
          {
            id: 'audit',
            label: 'Audit logs',
            path: '/admin/audit-logs',
            permission: AppPermission.auditRead,
            feature: 'audit_controls',
          },
          {
            id: 'settings',
            label: 'Settings',
            path: '/admin/system-settings',
            permission: AppPermission.auditRead,
          },
        ],
      },
    ],
    feature_flags: [
      'admin_governance',
      'moderation',
      'financial_controls',
      'audit_controls',
    ],
    permissions: ['*'],
    analytics_context: {
      experience: 'admin',
      north_star: 'platform_health',
    },
  },
};
