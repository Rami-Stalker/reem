import '../../domain/entities/admin_stats_entity.dart';

class AdminStatsModel extends AdminStatsEntity {
  const AdminStatsModel({
    required super.totalSales,
    required super.totalOrders,
    required super.activeUsers,
    required super.conversionRate,
    super.salesTrend,
    super.ordersTrend,
    super.usersTrend,
    super.conversionTrend,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
      activeUsers: json['active_users'] as int? ?? 0,
      conversionRate: (json['conversion_rate'] as num?)?.toDouble() ?? 0,
      salesTrend: json['sales_trend'] as String?,
      ordersTrend: json['orders_trend'] as String?,
      usersTrend: json['users_trend'] as String?,
      conversionTrend: json['conversion_trend'] as String?,
    );
  }
}
