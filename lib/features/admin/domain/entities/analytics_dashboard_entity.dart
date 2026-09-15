class AnalyticsPoint {
  const AnalyticsPoint({
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  final String label;
  final double value;
  final double? secondaryValue;
}

class AnalyticsRankedItem {
  const AnalyticsRankedItem({
    required this.title,
    required this.value,
    required this.units,
  });

  final String title;
  final double value;

  /// How many pieces moved. A number rather than a formatted line: the data
  /// layer has no locale, and the console is read in Arabic.
  final int units;
}

class AnalyticsDashboardEntity {
  const AnalyticsDashboardEntity({
    required this.grossRevenue,
    required this.netRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.activeCustomers,
    required this.repeatRate,
    required this.conversionRate,
    required this.retentionRate,
    required this.onlineUsers,
    required this.salesSeries,
    required this.funnel,
    required this.topProducts,
    required this.topSellers,
    required this.refreshedAt,
  });

  final double grossRevenue;
  final double netRevenue;
  final int totalOrders;
  final double averageOrderValue;
  final int activeCustomers;
  final double repeatRate;
  final double conversionRate;
  final double retentionRate;
  final int onlineUsers;
  final List<AnalyticsPoint> salesSeries;
  final List<AnalyticsPoint> funnel;
  final List<AnalyticsRankedItem> topProducts;
  final List<AnalyticsRankedItem> topSellers;
  final DateTime refreshedAt;
}
