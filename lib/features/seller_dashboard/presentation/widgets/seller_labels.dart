import 'package:reem/features/seller_dashboard/domain/entities/seller_analytics.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_chart_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_orders_summary.dart';
import 'package:reem/l10n/app_localizations.dart';

/// Localized labels for the dashboard's enums.
///
/// The entities carry English `label` getters, which is fine for a domain type
/// but wrong on screen: this app is Arabic-first, and a boutique owner in
/// Damascus was reading "Today / Week / Month". Translation belongs in the
/// presentation layer, so it lives here rather than in the entity — the domain
/// stays free of `AppLocalizations`.
extension RevenuePeriodLabel on RevenuePeriod {
  String labelOf(AppLocalizations l10n) => switch (this) {
    RevenuePeriod.today => l10n.periodToday,
    RevenuePeriod.week => l10n.periodWeek,
    RevenuePeriod.month => l10n.periodMonth,
    RevenuePeriod.year => l10n.periodYear,
  };
}

extension ChartPeriodLabel on ChartPeriod {
  String labelOf(AppLocalizations l10n) => switch (this) {
    ChartPeriod.daily => l10n.periodDaily,
    ChartPeriod.weekly => l10n.periodWeekly,
    ChartPeriod.monthly => l10n.periodMonthly,
    ChartPeriod.yearly => l10n.periodYearly,
  };
}

extension SellerOrderStatusLabel on SellerOrderStatus {
  String labelOf(AppLocalizations l10n) => switch (this) {
    SellerOrderStatus.newOrders => l10n.orderNew,
    SellerOrderStatus.processing => l10n.orderProcessing,
    SellerOrderStatus.readyForShipment => l10n.orderReady,
    SellerOrderStatus.delivered => l10n.orderDelivered,
    SellerOrderStatus.cancelled => l10n.orderCancelled,
    SellerOrderStatus.returned => l10n.orderReturned,
  };
}
