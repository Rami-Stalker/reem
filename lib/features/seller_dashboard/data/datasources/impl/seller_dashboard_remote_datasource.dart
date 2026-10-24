import 'package:flutter/material.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/seller_dashboard/data/datasources/seller_dashboard_datasource.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_analytics.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_chart_data.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_low_stock_item.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_misc.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_orders_summary.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_store_info.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_top_product.dart';

final class SellerDashboardRemoteDataSource extends BaseRemoteDataSource
    implements SellerDashboardDataSource {
  const SellerDashboardRemoteDataSource(super.dio);

  @override
  Future<SellerDashboardData> getDashboard() async {
    final json = await getJson(ApiEndpoints.sellerCommerceOverview);
    return _SellerDashboardMapper(json).toEntity();
  }
}

final class _SellerDashboardMapper {
  const _SellerDashboardMapper(this.json);

  final Map<String, dynamic> json;

  SellerDashboardData toEntity() {
    return SellerDashboardData(
      storeInfo: _storeInfo(_map(json['store_info'])),
      revenue: _revenue(_map(json['revenue'])),
      orders: _orders(_map(json['orders'])),
      charts: _charts(_map(json['charts'])),
      topProducts: _list(json['top_products']).map(_topProduct).toList(),
      lowStock: _list(json['low_stock']).map(_lowStock).toList(),
      storeScore: _storeScore(_map(json['store_score'])),
      conversionMetrics: _conversion(_map(json['conversion_metrics'])),
      aiInsights: _list(json['ai_insights']).map(_aiInsight).toList(),
      pendingTasks: _list(json['pending_tasks']).map(_task).toList(),
      goals: _list(json['goals']).map(_goal).toList(),
      recentReviews: _list(json['recent_reviews']).map(_review).toList(),
      campaigns: _list(json['campaigns']).map(_campaign).toList(),
    );
  }

  SellerStoreInfo _storeInfo(Map<String, dynamic> json) => SellerStoreInfo(
        id: _string(json['id']),
        name: _string(json['name'], fallback: 'Seller'),
        tagline: _string(json['tagline']),
        description: _string(json['description']),
        logoUrl: _string(json['logo_url']),
        coverUrl: _string(json['cover_url']),
        isVerified: _bool(json['is_verified']),
        rating: _double(json['rating']),
        reviewsCount: _int(json['reviews_count']),
        totalRevenue: _double(json['total_revenue']),
        totalOrders: _int(json['total_orders']),
        productsCount: _int(json['products_count']),
        followersCount: _int(json['followers_count']),
        storeScore: _int(json['store_score']),
        memberSince: _date(json['member_since']),
        subscriptionPlan: _string(json['subscription_plan'], fallback: 'Basic'),
        withdrawableBalance: _double(json['withdrawable_balance']),
      );

  SellerRevenueData _revenue(Map<String, dynamic> json) => SellerRevenueData(
        today: _double(json['today']),
        thisWeek: _double(json['this_week']),
        thisMonth: _double(json['this_month']),
        thisYear: _double(json['this_year']),
        todayTrend: _double(json['today_trend']),
        weekTrend: _double(json['week_trend']),
        monthTrend: _double(json['month_trend']),
        yearTrend: _double(json['year_trend']),
        totalProfit: _double(json['total_profit']),
        profitMargin: _double(json['profit_margin']),
        totalOrders: _int(json['total_orders']),
      );

  SellerOrdersSummary _orders(Map<String, dynamic> json) => SellerOrdersSummary(
        newOrders: _int(json['new_orders']),
        processing: _int(json['processing']),
        readyForShipment: _int(json['ready_for_shipment']),
        delivered: _int(json['delivered']),
        cancelled: _int(json['cancelled']),
        returned: _int(json['returned']),
      );

  Map<ChartPeriod, SellerChartDataset> _charts(Map<String, dynamic> json) => {
        ChartPeriod.daily:
            _dataset(ChartPeriod.daily, _map(json['daily'])),
        ChartPeriod.weekly:
            _dataset(ChartPeriod.weekly, _map(json['weekly'])),
        ChartPeriod.monthly:
            _dataset(ChartPeriod.monthly, _map(json['monthly'])),
        ChartPeriod.yearly:
            _dataset(ChartPeriod.yearly, _map(json['yearly'])),
      };

  SellerChartDataset _dataset(
    ChartPeriod period,
    Map<String, dynamic> json,
  ) {
    return SellerChartDataset(
      period: period,
      revenuePoints: _list(json['revenue_points']).map(_chartPoint).toList(),
      ordersPoints: _list(json['orders_points']).map(_chartPoint).toList(),
    );
  }

  SellerChartPoint _chartPoint(Map<String, dynamic> json) => SellerChartPoint(
        label: _string(json['label']),
        value: _double(json['value']),
      );

  SellerTopProduct _topProduct(Map<String, dynamic> json) => SellerTopProduct(
        id: _string(json['id']),
        title: _string(json['title']),
        imageUrl: _string(json['image_url']),
        revenue: _double(json['revenue']),
        unitsSold: _int(json['units_sold']),
        rating: _double(json['rating']),
        reviewsCount: _int(json['reviews_count']),
        stock: _int(json['stock']),
        revenueChange: json.containsKey('revenue_change')
            ? _nullableDouble(json['revenue_change'])
            : null,
      );

  SellerLowStockItem _lowStock(Map<String, dynamic> json) =>
      SellerLowStockItem(
        id: _string(json['id']),
        title: _string(json['title']),
        imageUrl: _string(json['image_url']),
        stock: _int(json['stock']),
        threshold: _int(json['threshold'], fallback: 10),
        price: _double(json['price']),
      );

  SellerStoreScore _storeScore(Map<String, dynamic> json) => SellerStoreScore(
        overall: _int(json['overall']),
        fulfillment: _int(json['fulfillment']),
        // Null stays null — see `SellerStoreScore.responsiveness`.
        responsiveness: json['responsiveness'] == null
            ? null
            : _int(json['responsiveness']),
        productQuality: _int(json['product_quality']),
        rating: _double(json['rating']),
      );

  SellerConversionMetrics _conversion(Map<String, dynamic> json) =>
      SellerConversionMetrics(
        productViews: _int(json['product_views']),
        wishlistAdds: _int(json['wishlist_adds']),
        cartAdds: _int(json['cart_adds']),
        purchases: _int(json['purchases']),
        viewsTrend: _double(json['views_trend']),
        wishlistTrend: _double(json['wishlist_trend']),
        cartTrend: _double(json['cart_trend']),
        conversionRate: _double(json['conversion_rate']),
        cartAbandonRate: _double(json['cart_abandon_rate']),
      );

  SellerAiInsight _aiInsight(Map<String, dynamic> json) => SellerAiInsight(
        id: _string(json['id']),
        kind: _aiKind(_string(json['kind'])),
        title: _string(json['title']),
        body: _string(json['body']),
        action: _string(json['action']),
      );

  SellerTask _task(Map<String, dynamic> json) {
    final kind = _string(json['kind']);
    return SellerTask(
      id: _string(json['id']),
      title: _string(json['title']),
      subtitle: _string(json['subtitle']),
      priority: _priority(_string(json['priority'])),
      icon: _taskIcon(kind),
      count: json.containsKey('count') ? _int(json['count']) : null,
    );
  }

  SellerGoal _goal(Map<String, dynamic> json) {
    final kind = _string(json['kind']);
    return SellerGoal(
      id: _string(json['id']),
      label: _string(json['label']),
      current: _double(json['current']),
      target: _double(json['target'], fallback: 1),
      unit: _string(json['unit']),
      icon: _goalIcon(kind),
    );
  }

  SellerRecentReview _review(Map<String, dynamic> json) => SellerRecentReview(
        id: _string(json['id']),
        customerName: _string(json['customer_name'], fallback: 'Customer'),
        customerAvatarUrl: _string(json['customer_avatar_url']),
        productTitle: _string(json['product_title']),
        rating: _double(json['rating']),
        body: _string(json['body']),
        timeAgo: _string(json['time_ago']),
      );

  SellerCampaignStat _campaign(Map<String, dynamic> json) => SellerCampaignStat(
        id: _string(json['id']),
        name: _string(json['name']),
        kind: _string(json['kind']),
        uses: _int(json['uses']),
        revenue: _double(json['revenue']),
        endsAt: _nullableDate(json['ends_at']),
        isActive: _bool(json['is_active']),
      );

  AiInsightKind _aiKind(String value) => switch (value) {
        'revenue' => AiInsightKind.revenue,
        'product' => AiInsightKind.product,
        'inventory' => AiInsightKind.inventory,
        'customer' => AiInsightKind.customer,
        _ => AiInsightKind.warning,
      };

  TaskPriority _priority(String value) => switch (value) {
        'high' => TaskPriority.high,
        'medium' => TaskPriority.medium,
        _ => TaskPriority.low,
      };

  IconData _taskIcon(String kind) => switch (kind) {
        'fulfillment' => Icons.local_shipping_outlined,
        'inventory' => Icons.inventory_2_outlined,
        'products' => Icons.inventory_outlined,
        'content' => Icons.dynamic_feed_outlined,
        'verification' => Icons.verified_outlined,
        'messages' => Icons.chat_bubble_outline_rounded,
        _ => Icons.task_alt_rounded,
      };

  IconData _goalIcon(String kind) => switch (kind) {
        'revenue' => Icons.attach_money_rounded,
        'orders' => Icons.shopping_bag_outlined,
        'products' => Icons.inventory_2_outlined,
        'rating' => Icons.star_outline_rounded,
        'followers' => Icons.people_outline_rounded,
        _ => Icons.flag_outlined,
      };

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    return _double(value);
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  DateTime _date(dynamic value) {
    return _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _nullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
