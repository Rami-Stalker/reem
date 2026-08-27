import 'package:equatable/equatable.dart';

import 'package:reem/features/seller_dashboard/domain/entities/seller_analytics.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_chart_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_low_stock_item.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_misc.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_orders_summary.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_store_info.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_top_product.dart';

/// Root entity for everything the seller dashboard needs.
class SellerDashboardData extends Equatable {
  const SellerDashboardData({
    required this.storeInfo,
    required this.revenue,
    required this.orders,
    required this.charts,
    required this.topProducts,
    required this.lowStock,
    required this.storeScore,
    required this.conversionMetrics,
    required this.aiInsights,
    required this.pendingTasks,
    required this.goals,
    required this.recentReviews,
    required this.campaigns,
  });

  final SellerStoreInfo storeInfo;
  final SellerRevenueData revenue;
  final SellerOrdersSummary orders;

  /// Pre-computed datasets for each chart period (indexed by [ChartPeriod]).
  final Map<ChartPeriod, SellerChartDataset> charts;

  final List<SellerTopProduct> topProducts;
  final List<SellerLowStockItem> lowStock;
  final SellerStoreScore storeScore;
  final SellerConversionMetrics conversionMetrics;
  final List<SellerAiInsight> aiInsights;
  final List<SellerTask> pendingTasks;
  final List<SellerGoal> goals;
  final List<SellerRecentReview> recentReviews;
  final List<SellerCampaignStat> campaigns;

  @override
  List<Object?> get props => [storeInfo.id, revenue.thisMonth];
}
