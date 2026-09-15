import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';

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
      grossRevenue: _money(revenue['gross_revenue']),
      netRevenue: _money(revenue['net_revenue']),
      totalOrders: _int(sales['total_orders']),
      averageOrderValue: _money(sales['average_order_value']),
      activeCustomers: _int(customers['active_customers']),
      repeatRate: _double(customers['repeat_rate']),
      conversionRate: _double(conversion['overall_conversion_rate']),
      retentionRate: _double(retention['retention_7d_rate']),
      onlineUsers: _int(realtime['online_users']),
      salesSeries: (_list(sales['series']))
          .map(
            (item) => AnalyticsPoint(
              label: item['date']?.toString() ?? '',
              value: _money(item['revenue']),
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
              value: _money(item['revenue']),
              units: _int(item['units']),
            ),
          )
          .toList(),
      topSellers: (_list(json['seller_performance']))
          .map(
            (item) => AnalyticsRankedItem(
              title: item['seller']?.toString() ?? 'Seller',
              value: _money(item['revenue']),
              units: _int(item['units']),
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

/// Reads a money figure off the analytics payload.
///
/// Every amount on this endpoint arrives as a **list** of `{amount, currency}`
/// — one entry per currency the window contained — because the platform can
/// hold SYP and USD side by side. Running that through `_double` produced
/// `double.tryParse("[{amount: 588860.0000, currency: SYP}]")`, which is
/// `null`, which is `0`: the business-intelligence screen reported gross
/// revenue, net revenue, average order value and every product and seller
/// ranking as zero while the dashboard beside it showed 713k.
///
/// The screen renders one figure in SYP, so that is the entry taken. A window
/// with only foreign currency in it falls back to the first entry rather than
/// showing nothing, which is wrong by the label but not by the magnitude —
/// and an all-USD window is not a state this platform reaches today.
double _money(dynamic value) {
  if (value is List) {
    if (value.isEmpty) return 0;
    final entries = value.whereType<Map>().toList();
    if (entries.isEmpty) return _double(value.first);
    final preferred = entries.firstWhere(
      (entry) => '${entry['currency']}'.toUpperCase() == Currency.syp.wire,
      orElse: () => entries.first,
    );
    return _double(preferred['amount']);
  }
  if (value is Map) return _double(value['amount']);
  return _double(value);
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
