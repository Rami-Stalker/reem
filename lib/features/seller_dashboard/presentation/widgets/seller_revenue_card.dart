import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../domain/entities/seller_analytics.dart';
import '../../domain/entities/seller_chart_data.dart';
import '../providers/seller_dashboard_provider.dart';
import 'seller_format.dart';
import 'seller_labels.dart';
import 'seller_mini_chart.dart';

/// The money card — the first figure a seller looks for.
///
/// Rebuilt on three counts. It quoted dollars on a platform that prices in
/// Syrian pounds; its sparkline was a hardcoded literal in the widget rather
/// than the store's own numbers; and it painted a fixed slate gradient that
/// ignored the theme. Now it reads SYP through [Money], draws the real series
/// from the dashboard's chart data, and wears the atelier's plum.
class SellerRevenueCard extends ConsumerWidget {
  const SellerRevenueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final notifier = ref.read(sellerDashboardNotifierProvider.notifier);
    final palette = context.atelier;
    final l10n = context.l10n;

    if (state.isInitialLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
          child: DsSkeleton.box(height: 214, borderRadius: DsRadius.xxl),
        ),
      );
    }

    final data = state.data;
    final revenue = data?.revenue;
    if (revenue == null) return const SizedBox.shrink();

    final period = state.selectedRevenuePeriod;
    final (value, trend) = _periodData(revenue, period);
    final spark = _sparkFor(data!.charts, period);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: palette.headerGradient,
          borderRadius: BorderRadius.circular(DsRadius.xxl),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.md,
                DsSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sellerRevenue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: DsTypography.labelMedium,
                        fontWeight: DsTypography.semiBold,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  _PeriodTabs(
                    selected: period,
                    onSelect: notifier.setRevenuePeriod,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.sm,
                DsSpacing.lg,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The figure is the reason the card exists, so it is
                        // animated with a framework switcher rather than an
                        // entrance effect: an effect that fails to finish
                        // leaves the hero number invisible, which is exactly
                        // what happened here.
                        AnimatedSwitcher(
                          duration: DsMotion.normal,
                          switchInCurve: DsMotion.emphasized,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              axis: Axis.horizontal,
                              axisAlignment: -1,
                              child: child,
                            ),
                          ),
                          child: FittedBox(
                            key: ValueKey(period),
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              value.sypFull,
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: DsTypography.fontFamily,
                                fontSize: 34,
                                fontWeight: DsTypography.bold,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: DsSpacing.xs),
                        _TrendBadge(trend: trend),
                      ],
                    ),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  MiniSparkline(
                    values: spark,
                    color: Colors.white,
                    width: 86,
                    height: 42,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.md,
                DsSpacing.lg,
                DsSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: l10n.sellerProfit,
                      value: revenue.totalProfit.sypCompact,
                    ),
                  ),
                  const _Divider(),
                  Expanded(
                    child: _Stat(
                      label: l10n.sellerMargin,
                      value: '${revenue.profitMargin.toStringAsFixed(1)}%',
                    ),
                  ),
                  const _Divider(),
                  Expanded(
                    child: _Stat(
                      label: l10n.orders,
                      value: formatCount(revenue.totalOrders),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (double, double) _periodData(
    SellerRevenueData revenue,
    RevenuePeriod period,
  ) => switch (period) {
    RevenuePeriod.today => (revenue.today, revenue.todayTrend),
    RevenuePeriod.week => (revenue.thisWeek, revenue.weekTrend),
    RevenuePeriod.month => (revenue.thisMonth, revenue.monthTrend),
    RevenuePeriod.year => (revenue.thisYear, revenue.yearTrend),
  };

  /// The sparkline reads the store's own series rather than a literal: each
  /// revenue period borrows the chart granularity that matches its shape.
  static List<double> _sparkFor(
    Map<ChartPeriod, SellerChartDataset> charts,
    RevenuePeriod period,
  ) {
    final granularity = switch (period) {
      RevenuePeriod.today => ChartPeriod.daily,
      RevenuePeriod.week => ChartPeriod.weekly,
      RevenuePeriod.month => ChartPeriod.monthly,
      RevenuePeriod.year => ChartPeriod.yearly,
    };
    final dataset = charts[granularity] ??
        (charts.isEmpty ? null : charts.values.first);
    return [for (final point in dataset?.revenuePoints ?? const []) point.value];
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelect});

  final RevenuePeriod selected;
  final ValueChanged<RevenuePeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: DsRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final period in RevenuePeriod.values)
            GestureDetector(
              onTap: () => onSelect(period),
              child: AnimatedContainer(
                duration: DsMotion.fast,
                curve: DsMotion.silk,
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.xs,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: period == selected
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: DsRadius.borderPill,
                ),
                child: Text(
                  period.labelOf(l10n),
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.labelSmall,
                    fontWeight: DsTypography.bold,
                    color: period == selected
                        ? context.atelier.primary
                        : Colors.white.withValues(alpha: 0.82),
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});

  final double trend;

  @override
  Widget build(BuildContext context) {
    final up = trend >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: DsRadius.borderPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 13,
                color: Colors.white,
              ),
              const SizedBox(width: 3),
              Text(
                formatTrend(trend),
                style: const TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: DsTypography.labelSmall,
                  fontWeight: DsTypography.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DsSpacing.xs),
        Flexible(
          child: Text(
            context.l10n.sellerVsPrior,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.labelSmall,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: DsTypography.labelSmall,
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.bold,
              color: Colors.white,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
    color: Colors.white.withValues(alpha: 0.16),
  );
}
