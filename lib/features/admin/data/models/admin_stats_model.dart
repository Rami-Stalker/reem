import 'package:reem/features/admin/domain/entities/admin_stats_entity.dart';

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

  /// The primary-currency total out of a per-currency list.
  ///
  /// `total_sales` is `[{amount, currency}]`, one entry per currency the
  /// platform has sold in — money is only ever summed within a currency. This
  /// used to be read as a bare `num`, which threw on the very first field of
  /// the very first admin screen and surfaced as "Unexpected error while
  /// running repository operation" where the takings should be.
  ///
  /// SYP is the figure the dashboard is labelled in (`.sypCompact`), so that
  /// is the entry taken; a platform selling only in another currency shows the
  /// one it has rather than nothing.
  static double _primaryTotal(Object? value) {
    if (value is num) return value.toDouble();
    if (value is! List) return 0;
    final entries = value.whereType<Map>();
    if (entries.isEmpty) return 0;
    final primary = entries.firstWhere(
      (entry) => entry['currency'] == 'SYP',
      orElse: () => entries.first,
    );
    final amount = primary['amount'];
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '') ?? 0;
  }

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalSales: _primaryTotal(json['total_sales']),
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
