import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/seller_analytics/domain/entities/seller_analytics_report.dart';

/// Parses `GET /analytics/dashboard`.
///
/// Every money field on this endpoint is an ARRAY of `{amount, currency}` —
/// the service aggregates within a currency and never across one, because
/// there is no rate at which SYP and USD may honestly be added. The mapper
/// keeps that shape rather than collapsing to a first element, so a seller
/// pricing in both sees both.
abstract final class SellerAnalyticsReportMapper {
  static SellerAnalyticsReport fromJson(Map<String, dynamic> json) {
    final range = _map(json['range']);
    final now = DateTime.now();

    return SellerAnalyticsReport(
      start: _date(range['start']) ?? now.subtract(const Duration(days: 30)),
      end: _date(range['end']) ?? now,
      sales: _sales(_map(json['sales'])),
      revenue: _revenue(_map(json['revenue'])),
      topProducts: [
        for (final row in _list(json['product_performance']))
          ProductPerformanceRow(
            productId: row['product_id'] as String? ?? '',
            title: row['title'] as String? ?? '',
            units: _int(row['units']),
            revenue: _money(row['revenue']),
          ),
      ],
      customers: _customers(_map(json['customers'])),
      conversion: _conversion(_map(json['conversion'])),
      funnel: [
        for (final row in _list(json['funnel']))
          FunnelStep(
            step: row['step'] as String? ?? '',
            count: _int(row['count']),
          ),
      ],
      retention: _retention(_map(json['retention'])),
      realtime: _realtime(_map(json['realtime'])),
    );
  }

  static SalesBreakdown _sales(Map<String, dynamic> json) => SalesBreakdown(
    totalOrders: _int(json['total_orders']),
    paidOrders: _int(json['paid_orders']),
    averageOrderValue: _money(json['average_order_value']),
    byStatus: {
      for (final row in _list(json['by_status']))
        if (row['status'] is String) row['status'] as String: _int(row['count']),
    },
    series: [
      for (final row in _list(json['series']))
        if (_date(row['date']) case final DateTime date)
          SalesSeriesPoint(
            date: date,
            orders: _int(row['orders']),
            revenue: _money(row['revenue']),
          ),
    ],
  );

  static RevenueBreakdown _revenue(Map<String, dynamic> json) =>
      RevenueBreakdown(
        gross: _money(json['gross_revenue']),
        paid: _money(json['paid_revenue']),
        refunds: _money(json['refunds']),
        net: _money(json['net_revenue']),
      );

  static CustomerBreakdown _customers(Map<String, dynamic> json) =>
      CustomerBreakdown(
        activeCustomers: _int(json['active_customers']),
        newCustomers: _int(json['new_customers']),
        repeatCustomers: _int(json['repeat_customers']),
        repeatRate: _double(json['repeat_rate']),
        averageCustomerValue: _money(json['average_customer_value']),
      );

  static ConversionBreakdown _conversion(Map<String, dynamic> json) =>
      ConversionBreakdown(
        productViews: _int(json['product_views']),
        cartAdds: _int(json['cart_adds']),
        checkoutStarts: _int(json['checkout_starts']),
        orders: _int(json['orders']),
        viewToCartRate: _double(json['view_to_cart_rate']),
        cartToCheckoutRate: _double(json['cart_to_checkout_rate']),
        checkoutToOrderRate: _double(json['checkout_to_order_rate']),
        overallRate: _double(json['overall_conversion_rate']),
      );

  static RetentionBreakdown _retention(Map<String, dynamic> json) =>
      RetentionBreakdown(
        customers: _int(json['customers']),
        retained7d: _int(json['retained_7d']),
        retained30d: _int(json['retained_30d']),
        retention7dRate: _double(json['retention_7d_rate']),
        retention30dRate: _double(json['retention_30d_rate']),
      );

  static RealtimeSnapshot _realtime(Map<String, dynamic> json) =>
      RealtimeSnapshot(
        todayOrders: _int(json['today_orders']),
        todayRevenue: _money(json['today_revenue']),
        activeCarts: _int(json['active_carts']),
        refreshedAt: _date(json['refreshed_at']),
      );

  // ── Primitives ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> _list(dynamic value) => [
    for (final row in (value is List ? value : const []))
      if (row is Map) row.cast<String, dynamic>(),
  ];

  static MoneyTotals _money(dynamic value) {
    if (value is List) {
      return [
        for (final row in value)
          if (Money.tryFromJson(row) case final Money money) money,
      ];
    }
    final single = Money.tryFromJson(value);
    return single == null ? const [] : [single];
  }

  static int _int(dynamic value) => switch (value) {
    final int v => v,
    final num v => v.round(),
    final String v => int.tryParse(v) ?? 0,
    _ => 0,
  };

  static double _double(dynamic value) => switch (value) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v) ?? 0,
    _ => 0,
  };

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
