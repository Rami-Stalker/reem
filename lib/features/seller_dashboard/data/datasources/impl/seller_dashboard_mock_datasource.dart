import 'package:flutter/material.dart';

import '../../../domain/entities/seller_analytics.dart';
import '../../../domain/entities/seller_chart_data.dart';
import '../../../domain/entities/seller_dashboard_data.dart';
import '../../../domain/entities/seller_low_stock_item.dart';
import '../../../domain/entities/seller_misc.dart';
import '../../../domain/entities/seller_orders_summary.dart';
import '../../../domain/entities/seller_store_info.dart';
import '../../../domain/entities/seller_top_product.dart';
import '../seller_dashboard_datasource.dart';

/// Front-end-first mock for the seller command centre. Simulated latency so
/// skeleton states are exercised. Swap with a remote implementation when
/// the backend analytics endpoints exist.
final class SellerDashboardMockDataSource
    implements SellerDashboardDataSource {
  const SellerDashboardMockDataSource();

  static const _latency = Duration(milliseconds: 700);
  static String _img(String seed, {int w = 400, int h = 400}) =>
      'https://picsum.photos/seed/$seed/$w/$h';

  @override
  Future<SellerDashboardData> getDashboard() async {
    await Future<void>.delayed(_latency);
    final now = DateTime.now();

    return SellerDashboardData(
      storeInfo: _storeInfo(now),
      revenue: _revenue,
      orders: _orders,
      charts: _charts,
      topProducts: _topProducts,
      lowStock: _lowStock,
      storeScore: _storeScore,
      conversionMetrics: _conversionMetrics,
      aiInsights: _aiInsights,
      pendingTasks: _tasks,
      goals: _goals,
      recentReviews: _reviews,
      campaigns: _campaigns(now),
    );
  }

  // ── Store info ─────────────────────────────────────────────────────────────
  static SellerStoreInfo _storeInfo(DateTime now) => SellerStoreInfo(
        id: 'store_001',
        name: 'Atelier Rose',
        tagline: 'Romantic ready-to-wear, handmade in small batches',
        description:
            'We craft heirloom-quality womenswear that feels as beautiful as '
            'the women who wear it — with love, locally, one piece at a time.',
        logoUrl: _img('logo-s1', w: 200, h: 200),
        coverUrl: _img('cover-store', w: 1200, h: 600),
        isVerified: true,
        rating: 4.9,
        reviewsCount: 1284,
        totalRevenue: 184300,
        totalOrders: 3420,
        productsCount: 248,
        followersCount: 32400,
        storeScore: 94,
        memberSince: DateTime(2023, 3, 14),
        subscriptionPlan: 'Pro',
        withdrawableBalance: 12840,
      );

  // ── Revenue ────────────────────────────────────────────────────────────────
  static const _revenue = SellerRevenueData(
    today: 1840,
    thisWeek: 14200,
    thisMonth: 58700,
    thisYear: 184300,
    todayTrend: 18.4,
    weekTrend: 12.7,
    monthTrend: 8.3,
    yearTrend: 34.2,
    totalProfit: 62340,
    profitMargin: 33.8,
    totalOrders: 3420,
  );

  // ── Orders ─────────────────────────────────────────────────────────────────
  static const _orders = SellerOrdersSummary(
    newOrders: 12,
    processing: 8,
    readyForShipment: 5,
    delivered: 3240,
    cancelled: 94,
    returned: 42,
  );

  // ── Chart data ─────────────────────────────────────────────────────────────
  static final _charts = <ChartPeriod, SellerChartDataset>{
    ChartPeriod.daily: SellerChartDataset(
      period: ChartPeriod.daily,
      revenuePoints: const [
        SellerChartPoint(label: '8am', value: 120),
        SellerChartPoint(label: '10am', value: 340),
        SellerChartPoint(label: '12pm', value: 580),
        SellerChartPoint(label: '2pm', value: 420),
        SellerChartPoint(label: '4pm', value: 680),
        SellerChartPoint(label: '6pm', value: 920),
        SellerChartPoint(label: '8pm', value: 1240),
        SellerChartPoint(label: '10pm', value: 1840),
      ],
      ordersPoints: const [
        SellerChartPoint(label: '8am', value: 2),
        SellerChartPoint(label: '10am', value: 5),
        SellerChartPoint(label: '12pm', value: 8),
        SellerChartPoint(label: '2pm', value: 6),
        SellerChartPoint(label: '4pm', value: 9),
        SellerChartPoint(label: '6pm', value: 12),
        SellerChartPoint(label: '8pm', value: 16),
        SellerChartPoint(label: '10pm', value: 22),
      ],
    ),
    ChartPeriod.weekly: SellerChartDataset(
      period: ChartPeriod.weekly,
      revenuePoints: const [
        SellerChartPoint(label: 'Mon', value: 1840),
        SellerChartPoint(label: 'Tue', value: 2340),
        SellerChartPoint(label: 'Wed', value: 1980),
        SellerChartPoint(label: 'Thu', value: 2680),
        SellerChartPoint(label: 'Fri', value: 3420),
        SellerChartPoint(label: 'Sat', value: 2100),
        SellerChartPoint(label: 'Sun', value: 1840),
      ],
      ordersPoints: const [
        SellerChartPoint(label: 'Mon', value: 28),
        SellerChartPoint(label: 'Tue', value: 36),
        SellerChartPoint(label: 'Wed', value: 30),
        SellerChartPoint(label: 'Thu', value: 42),
        SellerChartPoint(label: 'Fri', value: 54),
        SellerChartPoint(label: 'Sat', value: 32),
        SellerChartPoint(label: 'Sun', value: 28),
      ],
    ),
    ChartPeriod.monthly: SellerChartDataset(
      period: ChartPeriod.monthly,
      revenuePoints: const [
        SellerChartPoint(label: 'Jan', value: 12400),
        SellerChartPoint(label: 'Feb', value: 14800),
        SellerChartPoint(label: 'Mar', value: 18200),
        SellerChartPoint(label: 'Apr', value: 16400),
        SellerChartPoint(label: 'May', value: 21800),
        SellerChartPoint(label: 'Jun', value: 58700),
      ],
      ordersPoints: const [
        SellerChartPoint(label: 'Jan', value: 186),
        SellerChartPoint(label: 'Feb', value: 224),
        SellerChartPoint(label: 'Mar', value: 278),
        SellerChartPoint(label: 'Apr', value: 248),
        SellerChartPoint(label: 'May', value: 332),
        SellerChartPoint(label: 'Jun', value: 540),
      ],
    ),
    ChartPeriod.yearly: SellerChartDataset(
      period: ChartPeriod.yearly,
      revenuePoints: const [
        SellerChartPoint(label: '2021', value: 42000),
        SellerChartPoint(label: '2022', value: 86400),
        SellerChartPoint(label: '2023', value: 137200),
        SellerChartPoint(label: '2024', value: 184300),
      ],
      ordersPoints: const [
        SellerChartPoint(label: '2021', value: 640),
        SellerChartPoint(label: '2022', value: 1280),
        SellerChartPoint(label: '2023', value: 2040),
        SellerChartPoint(label: '2024', value: 3420),
      ],
    ),
  };

  // ── Top products ───────────────────────────────────────────────────────────
  static final _topProducts = <SellerTopProduct>[
    SellerTopProduct(
      id: 'p1',
      title: 'Rosewater Silk Slip Dress',
      imageUrl: _img('top-p1'),
      revenue: 18420,
      unitsSold: 97,
      rating: 4.9,
      reviewsCount: 284,
      stock: 23,
      revenueChange: 22.4,
    ),
    SellerTopProduct(
      id: 'p2',
      title: 'Velvet Bloom Eau de Parfum',
      imageUrl: _img('top-p2'),
      revenue: 12680,
      unitsSold: 134,
      rating: 4.8,
      reviewsCount: 198,
      stock: 7,
      revenueChange: 14.2,
    ),
    SellerTopProduct(
      id: 'p3',
      title: 'Quilted Mini Shoulder Bag',
      imageUrl: _img('top-p3'),
      revenue: 9840,
      unitsSold: 76,
      rating: 4.7,
      reviewsCount: 152,
      stock: 18,
      revenueChange: -3.8,
    ),
    SellerTopProduct(
      id: 'p4',
      title: 'Crystal Pearl Earring Set',
      imageUrl: _img('top-p4'),
      revenue: 8240,
      unitsSold: 168,
      rating: 4.8,
      reviewsCount: 241,
      stock: 2,
      revenueChange: 8.6,
    ),
    SellerTopProduct(
      id: 'p5',
      title: 'Satin Bow Heeled Mules',
      imageUrl: _img('top-p5'),
      revenue: 7120,
      unitsSold: 65,
      rating: 4.6,
      reviewsCount: 98,
      stock: 34,
      revenueChange: 5.1,
    ),
  ];

  // ── Low stock ──────────────────────────────────────────────────────────────
  static final _lowStock = <SellerLowStockItem>[
    SellerLowStockItem(
      id: 'ls1',
      title: 'Crystal Pearl Earring Set',
      imageUrl: _img('ls1'),
      stock: 2,
      threshold: 10,
      price: 49,
    ),
    SellerLowStockItem(
      id: 'ls2',
      title: 'Velvet Bloom Eau de Parfum',
      imageUrl: _img('ls2'),
      stock: 7,
      threshold: 15,
      price: 95,
    ),
    SellerLowStockItem(
      id: 'ls3',
      title: 'Amber Silk Hair Oil',
      imageUrl: _img('ls3'),
      stock: 0,
      threshold: 10,
      price: 38,
    ),
    SellerLowStockItem(
      id: 'ls4',
      title: 'Linen Wrap Maxi Dress — XS',
      imageUrl: _img('ls4'),
      stock: 3,
      threshold: 10,
      price: 156,
    ),
  ];

  // ── Store score ────────────────────────────────────────────────────────────
  static const _storeScore = SellerStoreScore(
    overall: 94,
    fulfillment: 97,
    responsiveness: 91,
    productQuality: 96,
    rating: 4.9,
  );

  // ── Conversion metrics ─────────────────────────────────────────────────────
  static const _conversionMetrics = SellerConversionMetrics(
    productViews: 48200,
    wishlistAdds: 6840,
    cartAdds: 3920,
    purchases: 3240,
    viewsTrend: 14.2,
    wishlistTrend: 8.6,
    cartTrend: 11.4,
    conversionRate: 6.72,
    cartAbandonRate: 17.3,
  );

  // ── AI insights ────────────────────────────────────────────────────────────
  static const _aiInsights = <SellerAiInsight>[
    SellerAiInsight(
      id: 'ai1',
      kind: AiInsightKind.revenue,
      title: 'Revenue spike incoming',
      body: 'Your "Silk Slip Dress" has 3× the usual wishlist saves this week '
          '— consider a limited flash deal to convert them.',
      action: 'Create flash deal',
    ),
    SellerAiInsight(
      id: 'ai2',
      kind: AiInsightKind.inventory,
      title: 'Restock 4 items now',
      body: 'Crystal earrings (2 left) and Amber Oil (0) are selling faster '
          'than your replenishment lead time. Order today.',
      action: 'View low stock',
    ),
    SellerAiInsight(
      id: 'ai3',
      kind: AiInsightKind.product,
      title: 'Add more bag colours',
      body: 'Customers who bought the Quilted Bag searched for it in "ivory" '
          'and "tan" — 0 listings for those colours.',
      action: 'Add variant',
    ),
    SellerAiInsight(
      id: 'ai4',
      kind: AiInsightKind.customer,
      title: 'High repeat-buyer rate',
      body: '38% of your orders this month are from returning customers — '
          'launch a loyalty campaign to reward them.',
      action: 'Create coupon',
    ),
  ];

  // ── Tasks ──────────────────────────────────────────────────────────────────
  static const _tasks = <SellerTask>[
    SellerTask(
      id: 't1',
      title: 'Respond to 5 messages',
      subtitle: 'Customers waiting · avg 4h',
      priority: TaskPriority.high,
      icon: Icons.chat_bubble_outline_rounded,
      count: 5,
    ),
    SellerTask(
      id: 't2',
      title: 'Ship 5 ready orders',
      subtitle: 'Cut-off in 2 hours',
      priority: TaskPriority.high,
      icon: Icons.local_shipping_outlined,
      count: 5,
    ),
    SellerTask(
      id: 't3',
      title: 'Review 3 return requests',
      subtitle: 'Action required within 48h',
      priority: TaskPriority.medium,
      icon: Icons.keyboard_return_rounded,
      count: 3,
    ),
    SellerTask(
      id: 't4',
      title: 'Complete store profile',
      subtitle: 'Boost discoverability by 40%',
      priority: TaskPriority.low,
      icon: Icons.storefront_outlined,
    ),
  ];

  // ── Goals ──────────────────────────────────────────────────────────────────
  static const _goals = <SellerGoal>[
    SellerGoal(
      id: 'g1',
      label: 'Monthly revenue',
      current: 58700,
      target: 70000,
      unit: '\$',
      icon: Icons.attach_money_rounded,
    ),
    SellerGoal(
      id: 'g2',
      label: 'Orders this month',
      current: 540,
      target: 600,
      unit: '',
      icon: Icons.shopping_bag_outlined,
    ),
    SellerGoal(
      id: 'g3',
      label: 'New followers',
      current: 1240,
      target: 2000,
      unit: '',
      icon: Icons.people_outline_rounded,
    ),
    SellerGoal(
      id: 'g4',
      label: 'Store rating',
      current: 4.9,
      target: 5.0,
      unit: '★',
      icon: Icons.star_outline_rounded,
    ),
  ];

  // ── Recent reviews ─────────────────────────────────────────────────────────
  static final _reviews = <SellerRecentReview>[
    SellerRecentReview(
      id: 'r1',
      customerName: 'Layla M.',
      customerAvatarUrl: _img('av1', w: 100, h: 100),
      productTitle: 'Rosewater Silk Slip Dress',
      rating: 5,
      body: 'Absolute perfection. Wore it to a wedding and got so many compliments. '
          'The quality is unmatched.',
      timeAgo: '2h',
    ),
    SellerRecentReview(
      id: 'r2',
      customerName: 'Sara K.',
      customerAvatarUrl: _img('av2', w: 100, h: 100),
      productTitle: 'Velvet Bloom Eau de Parfum',
      rating: 5,
      body: 'The scent lasts all day and the bottle is gorgeous. Already ordered '
          'a second one as a gift.',
      timeAgo: '5h',
    ),
    SellerRecentReview(
      id: 'r3',
      customerName: 'Nour A.',
      customerAvatarUrl: _img('av3', w: 100, h: 100),
      productTitle: 'Quilted Mini Shoulder Bag',
      rating: 4,
      body: 'Beautiful bag, love the quality. The strap is slightly shorter than '
          'I expected but still stylish.',
      timeAgo: '1d',
    ),
  ];

  // ── Campaigns ─────────────────────────────────────────────────────────────
  static List<SellerCampaignStat> _campaigns(DateTime now) => [
        SellerCampaignStat(
          id: 'c1',
          name: 'Summer Edit 20% Off',
          kind: 'Coupon',
          uses: 184,
          revenue: 14280,
          endsAt: now.add(const Duration(days: 5)),
          isActive: true,
        ),
        SellerCampaignStat(
          id: 'c2',
          name: 'New Arrival Launch',
          kind: 'Campaign',
          uses: 96,
          revenue: 8640,
          endsAt: now.add(const Duration(days: 2)),
          isActive: true,
        ),
        SellerCampaignStat(
          id: 'c3',
          name: 'Flash Deal – Bags',
          kind: 'Flash',
          uses: 234,
          revenue: 22800,
          endsAt: now.subtract(const Duration(days: 3)),
          isActive: false,
        ),
      ];
}
