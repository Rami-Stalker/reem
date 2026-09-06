import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';

/// The window a report covers.
///
/// The seller picks a length, not two dates: «آخر ٣٠ يوماً» is the question
/// she actually asks, and a date-range picker for it would be three taps to
/// express the default.
enum AnalyticsPeriod {
  week(7),
  month(30),
  quarter(90),
  year(365);

  const AnalyticsPeriod(this.days);

  final int days;

  DateTime startFrom(DateTime end) => end.subtract(Duration(days: days));
}

/// Money in this report arrives as a LIST of totals, one per currency.
///
/// The server refuses to add SYP to USD, and it is right to: there is no
/// platform exchange rate a figure could honestly be converted at. So a total
/// is a list, rendered as a list, and a seller pricing in both currencies sees
/// both lines rather than one invented number.
typedef MoneyTotals = List<Money>;

class SalesSeriesPoint extends Equatable {
  const SalesSeriesPoint({
    required this.date,
    required this.orders,
    required this.revenue,
  });

  final DateTime date;
  final int orders;
  final MoneyTotals revenue;

  /// For plotting only — the first currency's magnitude. A chart axis is a
  /// shape, not a figure the seller is paid.
  double get plottableRevenue =>
      revenue.isEmpty ? 0 : revenue.first.approximateValue;

  @override
  List<Object?> get props => [date, orders, revenue];
}

class SalesBreakdown extends Equatable {
  const SalesBreakdown({
    this.totalOrders = 0,
    this.paidOrders = 0,
    this.averageOrderValue = const [],
    this.byStatus = const {},
    this.series = const [],
  });

  final int totalOrders;

  /// Orders with at least one parcel that has reached a revenue-bearing state.
  final int paidOrders;
  final MoneyTotals averageOrderValue;
  final Map<String, int> byStatus;
  final List<SalesSeriesPoint> series;

  @override
  List<Object?> get props => [
    totalOrders,
    paidOrders,
    averageOrderValue,
    byStatus,
    series,
  ];
}

class RevenueBreakdown extends Equatable {
  const RevenueBreakdown({
    this.gross = const [],
    this.paid = const [],
    this.refunds = const [],
    this.net = const [],
  });

  final MoneyTotals gross;
  final MoneyTotals paid;
  final MoneyTotals refunds;
  final MoneyTotals net;

  @override
  List<Object?> get props => [gross, paid, refunds, net];
}

class ProductPerformanceRow extends Equatable {
  const ProductPerformanceRow({
    required this.productId,
    required this.title,
    required this.units,
    required this.revenue,
  });

  final String productId;
  final String title;
  final int units;
  final MoneyTotals revenue;

  @override
  List<Object?> get props => [productId, title, units, revenue];
}

class CustomerBreakdown extends Equatable {
  const CustomerBreakdown({
    this.activeCustomers = 0,
    this.newCustomers = 0,
    this.repeatCustomers = 0,
    this.repeatRate = 0,
    this.averageCustomerValue = const [],
  });

  final int activeCustomers;
  final int newCustomers;
  final int repeatCustomers;

  /// A percentage, already computed server-side.
  final double repeatRate;
  final MoneyTotals averageCustomerValue;

  @override
  List<Object?> get props => [
    activeCustomers,
    newCustomers,
    repeatCustomers,
    repeatRate,
    averageCustomerValue,
  ];
}

class ConversionBreakdown extends Equatable {
  const ConversionBreakdown({
    this.productViews = 0,
    this.cartAdds = 0,
    this.checkoutStarts = 0,
    this.orders = 0,
    this.viewToCartRate = 0,
    this.cartToCheckoutRate = 0,
    this.checkoutToOrderRate = 0,
    this.overallRate = 0,
  });

  final int productViews;
  final int cartAdds;
  final int checkoutStarts;
  final int orders;
  final double viewToCartRate;
  final double cartToCheckoutRate;
  final double checkoutToOrderRate;
  final double overallRate;

  @override
  List<Object?> get props => [
    productViews,
    cartAdds,
    checkoutStarts,
    orders,
    viewToCartRate,
    cartToCheckoutRate,
    checkoutToOrderRate,
    overallRate,
  ];
}

class FunnelStep extends Equatable {
  const FunnelStep({required this.step, required this.count});

  final String step;
  final int count;

  @override
  List<Object?> get props => [step, count];
}

class RetentionBreakdown extends Equatable {
  const RetentionBreakdown({
    this.customers = 0,
    this.retained7d = 0,
    this.retained30d = 0,
    this.retention7dRate = 0,
    this.retention30dRate = 0,
  });

  final int customers;
  final int retained7d;
  final int retained30d;
  final double retention7dRate;
  final double retention30dRate;

  @override
  List<Object?> get props => [
    customers,
    retained7d,
    retained30d,
    retention7dRate,
    retention30dRate,
  ];
}

class RealtimeSnapshot extends Equatable {
  const RealtimeSnapshot({
    this.todayOrders = 0,
    this.todayRevenue = const [],
    this.activeCarts = 0,
    this.refreshedAt,
  });

  final int todayOrders;
  final MoneyTotals todayRevenue;

  /// Carts holding this seller's goods right now — demand that has not yet
  /// become an order, and the one figure here she can still act on today.
  final int activeCarts;
  final DateTime? refreshedAt;

  @override
  List<Object?> get props => [
    todayOrders,
    todayRevenue,
    activeCarts,
    refreshedAt,
  ];
}

/// Everything `GET /analytics/dashboard` answers with, scoped by the server to
/// the signed-in seller.
class SellerAnalyticsReport extends Equatable {
  const SellerAnalyticsReport({
    required this.start,
    required this.end,
    this.sales = const SalesBreakdown(),
    this.revenue = const RevenueBreakdown(),
    this.topProducts = const [],
    this.customers = const CustomerBreakdown(),
    this.conversion = const ConversionBreakdown(),
    this.funnel = const [],
    this.retention = const RetentionBreakdown(),
    this.realtime = const RealtimeSnapshot(),
  });

  final DateTime start;
  final DateTime end;
  final SalesBreakdown sales;
  final RevenueBreakdown revenue;
  final List<ProductPerformanceRow> topProducts;
  final CustomerBreakdown customers;
  final ConversionBreakdown conversion;
  final List<FunnelStep> funnel;
  final RetentionBreakdown retention;
  final RealtimeSnapshot realtime;

  /// True when the window holds nothing at all — no orders and no browsing.
  /// Worth distinguishing from a failed load: a new shop's honest answer is
  /// zero, and showing it an error would be a lie.
  bool get isEmpty =>
      sales.totalOrders == 0 && conversion.productViews == 0;

  @override
  List<Object?> get props => [
    start,
    end,
    sales,
    revenue,
    topProducts,
    customers,
    conversion,
    funnel,
    retention,
    realtime,
  ];
}
