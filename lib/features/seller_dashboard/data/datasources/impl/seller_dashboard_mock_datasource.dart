import 'package:flutter/material.dart';
import 'package:reem/features/seller_dashboard/data/datasources/seller_dashboard_datasource.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_analytics.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_chart_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_low_stock_item.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_misc.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_orders_summary.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_store_info.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_top_product.dart';

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
        name: 'أتيليه الورد',
        tagline: 'أزياء رومانسية جاهزة، تُخاط يدوياً بكميّات قليلة',
        description:
            'نصنع أزياءً نسائية تدوم كإرث، تليق بجمال من ترتديها — بحبّ، '
            'وهنا، قطعةً قطعة.',
        logoUrl: _img('logo-s1', w: 200, h: 200),
        coverUrl: _img('cover-store', w: 1200, h: 600),
        isVerified: true,
        rating: 4.9,
        reviewsCount: 1284,
        totalRevenue: 829350000,
        totalOrders: 3420,
        productsCount: 248,
        followersCount: 32400,
        storeScore: 94,
        memberSince: DateTime(2023, 3, 14),
        subscriptionPlan: 'برو',
        withdrawableBalance: 57780000,
      );

  // ── Revenue ────────────────────────────────────────────────────────────────
  static const _revenue = SellerRevenueData(
    today: 8280000,
    thisWeek: 63900000,
    thisMonth: 264150000,
    thisYear: 829350000,
    todayTrend: 18.4,
    weekTrend: 12.7,
    monthTrend: 8.3,
    yearTrend: 34.2,
    totalProfit: 280530000,
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
        SellerChartPoint(label: '8ص', value: 540000),
        SellerChartPoint(label: '10ص', value: 1530000),
        SellerChartPoint(label: '12ظ', value: 2610000),
        SellerChartPoint(label: '2م', value: 1890000),
        SellerChartPoint(label: '4م', value: 3060000),
        SellerChartPoint(label: '6م', value: 4140000),
        SellerChartPoint(label: '8م', value: 5580000),
        SellerChartPoint(label: '10م', value: 8280000),
      ],
      ordersPoints: const [
        SellerChartPoint(label: '8ص', value: 2),
        SellerChartPoint(label: '10ص', value: 5),
        SellerChartPoint(label: '12ظ', value: 8),
        SellerChartPoint(label: '2م', value: 6),
        SellerChartPoint(label: '4م', value: 9),
        SellerChartPoint(label: '6م', value: 12),
        SellerChartPoint(label: '8م', value: 16),
        SellerChartPoint(label: '10م', value: 22),
      ],
    ),
    ChartPeriod.weekly: SellerChartDataset(
      period: ChartPeriod.weekly,
      revenuePoints: const [
        SellerChartPoint(label: 'اث', value: 8280000),
        SellerChartPoint(label: 'ثل', value: 10530000),
        SellerChartPoint(label: 'أر', value: 8910000),
        SellerChartPoint(label: 'خم', value: 12060000),
        SellerChartPoint(label: 'جم', value: 15390000),
        SellerChartPoint(label: 'سب', value: 9450000),
        SellerChartPoint(label: 'أح', value: 8280000),
      ],
      ordersPoints: const [
        SellerChartPoint(label: 'اث', value: 28),
        SellerChartPoint(label: 'ثل', value: 36),
        SellerChartPoint(label: 'أر', value: 30),
        SellerChartPoint(label: 'خم', value: 42),
        SellerChartPoint(label: 'جم', value: 54),
        SellerChartPoint(label: 'سب', value: 32),
        SellerChartPoint(label: 'أح', value: 28),
      ],
    ),
    ChartPeriod.monthly: SellerChartDataset(
      period: ChartPeriod.monthly,
      revenuePoints: const [
        SellerChartPoint(label: 'كانون2', value: 55800000),
        SellerChartPoint(label: 'شباط', value: 66600000),
        SellerChartPoint(label: 'آذار', value: 81900000),
        SellerChartPoint(label: 'نيسان', value: 73800000),
        SellerChartPoint(label: 'أيار', value: 98100000),
        SellerChartPoint(label: 'حزيران', value: 264150000),
      ],
      ordersPoints: const [
        SellerChartPoint(label: 'كانون2', value: 186),
        SellerChartPoint(label: 'شباط', value: 224),
        SellerChartPoint(label: 'آذار', value: 278),
        SellerChartPoint(label: 'نيسان', value: 248),
        SellerChartPoint(label: 'أيار', value: 332),
        SellerChartPoint(label: 'حزيران', value: 540),
      ],
    ),
    ChartPeriod.yearly: SellerChartDataset(
      period: ChartPeriod.yearly,
      revenuePoints: const [
        SellerChartPoint(label: '2021', value: 189000000),
        SellerChartPoint(label: '2022', value: 388800000),
        SellerChartPoint(label: '2023', value: 617400000),
        SellerChartPoint(label: '2024', value: 829350000),
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
      title: 'فستان حرير بماء الورد',
      imageUrl: _img('top-p1'),
      revenue: 82890000,
      unitsSold: 97,
      rating: 4.9,
      reviewsCount: 284,
      stock: 23,
      revenueChange: 22.4,
    ),
    SellerTopProduct(
      id: 'p2',
      title: 'عطر زهر المخمل',
      imageUrl: _img('top-p2'),
      revenue: 57060000,
      unitsSold: 134,
      rating: 4.8,
      reviewsCount: 198,
      stock: 7,
      revenueChange: 14.2,
    ),
    SellerTopProduct(
      id: 'p3',
      title: 'حقيبة كتف صغيرة مبطّنة',
      imageUrl: _img('top-p3'),
      revenue: 44280000,
      unitsSold: 76,
      rating: 4.7,
      reviewsCount: 152,
      stock: 18,
      revenueChange: -3.8,
    ),
    SellerTopProduct(
      id: 'p4',
      title: 'طقم أقراط لؤلؤ وكريستال',
      imageUrl: _img('top-p4'),
      revenue: 37080000,
      unitsSold: 168,
      rating: 4.8,
      reviewsCount: 241,
      stock: 2,
      revenueChange: 8.6,
    ),
    SellerTopProduct(
      id: 'p5',
      title: 'حذاء ساتان بفيونكة',
      imageUrl: _img('top-p5'),
      revenue: 32040000,
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
      title: 'طقم أقراط لؤلؤ وكريستال',
      imageUrl: _img('ls1'),
      stock: 2,
      threshold: 10,
      price: 220500,
    ),
    SellerLowStockItem(
      id: 'ls2',
      title: 'عطر زهر المخمل',
      imageUrl: _img('ls2'),
      stock: 7,
      threshold: 15,
      price: 427500,
    ),
    SellerLowStockItem(
      id: 'ls3',
      title: 'زيت شعر بالعنبر والحرير',
      imageUrl: _img('ls3'),
      stock: 0,
      threshold: 10,
      price: 171000,
    ),
    SellerLowStockItem(
      id: 'ls4',
      title: 'فستان كتّان ماكسي بلفّة — قياس صغير',
      imageUrl: _img('ls4'),
      stock: 3,
      threshold: 10,
      price: 702000,
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
      title: 'ارتفاع قادم في المبيعات',
      body: 'فستان الحرير حُفظ في المفضّلة ثلاثة أضعاف المعتاد هذا الأسبوع — '
          'عرض سريع محدود قد يحوّل هذا الاهتمام إلى طلبات.',
      action: 'إنشاء عرض سريع',
    ),
    SellerAiInsight(
      id: 'ai2',
      kind: AiInsightKind.inventory,
      title: 'أعيدي توريد 4 أصناف الآن',
      body: 'أقراط الكريستال (بقيت 2) وزيت العنبر (نفد) يُباعان أسرع من مدّة '
          'التوريد لديكِ. اطلبيها اليوم.',
      action: 'عرض المخزون المنخفض',
    ),
    SellerAiInsight(
      id: 'ai3',
      kind: AiInsightKind.product,
      title: 'أضيفي ألواناً للحقيبة',
      body: 'من اشترين الحقيبة المبطّنة بحثن عنها بلون العاج والبيج — '
          'ولا يوجد أي إعلان بهذين اللونين.',
      action: 'إضافة خيار',
    ),
    SellerAiInsight(
      id: 'ai4',
      kind: AiInsightKind.customer,
      title: 'نسبة عالية من الزبونات العائدات',
      body: '38٪ من طلبات هذا الشهر جاءت من زبونات عائدات — أطلقي حملة وفاء '
          'تكافئهنّ عليها.',
      action: 'إنشاء كوبون',
    ),
  ];

  // ── Tasks ──────────────────────────────────────────────────────────────────
  static const _tasks = <SellerTask>[
    SellerTask(
      id: 't1',
      title: 'ردّي على 5 رسائل',
      subtitle: 'زبونات بانتظاركِ · متوسط 4 ساعات',
      priority: TaskPriority.high,
      icon: Icons.chat_bubble_outline_rounded,
      count: 5,
    ),
    SellerTask(
      id: 't2',
      title: 'اشحني 5 طلبات جاهزة',
      subtitle: 'آخر موعد بعد ساعتين',
      priority: TaskPriority.high,
      icon: Icons.local_shipping_outlined,
      count: 5,
    ),
    SellerTask(
      id: 't3',
      title: 'راجعي 3 طلبات إرجاع',
      subtitle: 'تحتاج قراراً خلال 48 ساعة',
      priority: TaskPriority.medium,
      icon: Icons.keyboard_return_rounded,
      count: 3,
    ),
    SellerTask(
      id: 't4',
      title: 'أكملي ملف المتجر',
      subtitle: 'يرفع ظهوركِ في البحث بنسبة 40٪',
      priority: TaskPriority.low,
      icon: Icons.storefront_outlined,
    ),
  ];

  // ── Goals ──────────────────────────────────────────────────────────────────
  static const _goals = <SellerGoal>[
    SellerGoal(
      id: 'g1',
      label: 'إيرادات الشهر',
      current: 264150000,
      target: 315000000,
      unit: '',
      icon: Icons.payments_outlined,
    ),
    SellerGoal(
      id: 'g2',
      label: 'طلبات هذا الشهر',
      current: 540,
      target: 600,
      unit: '',
      icon: Icons.shopping_bag_outlined,
    ),
    SellerGoal(
      id: 'g3',
      label: 'متابِعات جديدات',
      current: 1240,
      target: 2000,
      unit: '',
      icon: Icons.people_outline_rounded,
    ),
    SellerGoal(
      id: 'g4',
      label: 'تقييم المتجر',
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
      customerName: 'ليلى م.',
      customerAvatarUrl: _img('av1', w: 100, h: 100),
      productTitle: 'فستان حرير بماء الورد',
      rating: 5,
      body: 'رائع بكل معنى الكلمة. لبستُه في عرس وانهالت عليّ المجاملات. '
          'الخامة لا تُضاهى.',
      timeAgo: 'قبل ساعتين',
    ),
    SellerRecentReview(
      id: 'r2',
      customerName: 'سارة ك.',
      customerAvatarUrl: _img('av2', w: 100, h: 100),
      productTitle: 'عطر زهر المخمل',
      rating: 5,
      body: 'العطر يثبت طوال اليوم والزجاجة تحفة. طلبتُ ثانية لتكون هديّة.',
      timeAgo: 'قبل 5 ساعات',
    ),
    SellerRecentReview(
      id: 'r3',
      customerName: 'نور ع.',
      customerAvatarUrl: _img('av3', w: 100, h: 100),
      productTitle: 'حقيبة كتف صغيرة مبطّنة',
      rating: 4,
      body: 'حقيبة جميلة وخامتها ممتازة. الحزام أقصر قليلاً مما توقّعت لكنها '
          'ما زالت أنيقة.',
      timeAgo: 'قبل يوم',
    ),
  ];

  // ── Campaigns ─────────────────────────────────────────────────────────────
  static List<SellerCampaignStat> _campaigns(DateTime now) => [
        SellerCampaignStat(
          id: 'c1',
          name: 'مختارات الصيف — خصم 20٪',
          kind: 'كوبون',
          uses: 184,
          revenue: 64260000,
          endsAt: now.add(const Duration(days: 5)),
          isActive: true,
        ),
        SellerCampaignStat(
          id: 'c2',
          name: 'إطلاق الوصول الجديد',
          kind: 'حملة',
          uses: 96,
          revenue: 38880000,
          endsAt: now.add(const Duration(days: 2)),
          isActive: true,
        ),
        SellerCampaignStat(
          id: 'c3',
          name: 'عرض سريع — حقائب',
          kind: 'عرض سريع',
          uses: 234,
          revenue: 102600000,
          endsAt: now.subtract(const Duration(days: 3)),
          isActive: false,
        ),
      ];
}
