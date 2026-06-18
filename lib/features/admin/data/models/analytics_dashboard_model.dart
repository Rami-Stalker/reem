import '../../domain/entities/analytics_dashboard_entity.dart';

class AnalyticsDashboardModel extends AnalyticsDashboardEntity {
  const AnalyticsDashboardModel({
    required super.grossRevenue,
    required super.netRevenue,
    required super.totalOrders,
    required super.averageOrderValue,
    required super.activeCustomers,
    required super.repeatRate,
    required super.conversionRate,
    required super.retentionRate,
    required super.onlineUsers,
    required super.salesSeries,
    required super.funnel,
    required super.topProducts,
    required super.topSellers,
    required super.refreshedAt,
  });

  factory AnalyticsDashboardModel.fromJson(Map<String, dynamic> json) {
    final sales = _map(json['sales']);
    final revenue = _map(json['revenue']);
    final customers = _map(json['customers']);
    final conversion = _map(json['conversion']);
    final retention = _map(json['retention']);
    final realtime = _map(json['realtime']);
    return AnalyticsDashboardModel(
      grossRevenue: _double(revenue['gross_revenue']),
      netRevenue: _double(revenue['net_revenue']),
      totalOrders: _int(sales['total_orders']),
      averageOrderValue: _double(sales['average_order_value']),
      activeCustomers: _int(customers['active_customers']),
      repeatRate: _double(customers['repeat_rate']),
      conversionRate: _double(conversion['overall_conversion_rate']),
      retentionRate: _double(retention['retention_7d_rate']),
      onlineUsers: _int(realtime['online_users']),
      salesSeries: (_list(sales['series']))
          .map(
            (item) => AnalyticsPoint(
              label: item['date']?.toString() ?? '',
              value: _double(item['revenue']),
              secondaryValue: _double(item['orders']),
            ),
          )
          .toList(),
      funnel: (_list(json['funnel']))
          .map(
            (item) => AnalyticsPoint(
              label: item['step']?.toString() ?? '',
              value: _double(item['count']),
            ),
          )
          .toList(),
      topProducts: (_list(json['product_performance']))
          .map(
            (item) => AnalyticsRankedItem(
              title: item['title']?.toString() ?? 'Product',
              value: _double(item['revenue']),
              subtitle: '${_int(item['units'])} units',
            ),
          )
          .toList(),
      topSellers: (_list(json['seller_performance']))
          .map(
            (item) => AnalyticsRankedItem(
              title: item['seller']?.toString() ?? 'Seller',
              value: _double(item['revenue']),
              subtitle: '${_int(item['units'])} units',
            ),
          )
          .toList(),
      refreshedAt: DateTime.tryParse(
            realtime['refreshed_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
