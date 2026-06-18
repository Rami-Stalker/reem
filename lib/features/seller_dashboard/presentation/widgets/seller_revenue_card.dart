import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../domain/entities/seller_analytics.dart';
import '../providers/seller_dashboard_provider.dart';
import 'seller_mini_chart.dart';

/// The revenue dashboard card — period tabs (Today/Week/Month/Year) with a live
/// revenue figure, profit split, trend arrow and a mini sparkline.
class SellerRevenueCard extends ConsumerWidget {
  const SellerRevenueCard({super.key});

  // Sparkline seeds per period (static mock values — replace with chart data).
  static const _sparks = <RevenuePeriod, List<double>>{
    RevenuePeriod.today: [120, 340, 580, 420, 680, 920, 1240, 1840],
    RevenuePeriod.week: [1840, 2340, 1980, 2680, 3420, 2100, 1840],
    RevenuePeriod.month: [12400, 14800, 18200, 16400, 21800, 58700],
    RevenuePeriod.year: [42000, 86400, 137200, 184300],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final notifier = ref.read(sellerDashboardNotifierProvider.notifier);
    final c = context.dsColors;

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 210, borderRadius: DsRadius.xxl)),
      );
    }

    final revenue = state.data?.revenue;
    if (revenue == null) return const SizedBox.shrink();

    final period = state.selectedRevenuePeriod;
    final (value, trend) = _periodData(revenue, period);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: context.primaryGradient,
          borderRadius: DsRadius.borderXxl,
          boxShadow:
              context.glowShadow(c.primary, blur: 32, alpha: 0.28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period tabs.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg, DsSpacing.md, DsSpacing.md, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Revenue',
                      style: TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: DsTypography.labelMedium,
                        fontWeight: DsTypography.semiBold,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  _PeriodTabs(selected: period, onSelect: notifier.setRevenuePeriod),
                ],
              ),
            ),

            // Revenue + sparkline.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${_format(value)}',
                          style: const TextStyle(
                            fontFamily: DsTypography.fontFamilyDisplay,
                            fontFamilyFallback: DsTypography.displayFallback,
                            fontSize: 38,
                            fontWeight: DsTypography.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        )
                            .animate(key: ValueKey(period))
                            .fadeIn(duration: 280.ms)
                            .slideY(begin: 0.2, end: 0, duration: 280.ms),
                        const SizedBox(height: DsSpacing.xs),
                        _TrendBadge(trend: trend),
                      ],
                    ),
                  ),
                  MiniSparkline(
                    values: _sparks[period] ?? [],
                    color: Colors.white,
                    width: 90,
                    height: 44,
                  ),
                ],
              ),
            ),

            // Profit strip.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg, DsSpacing.md, DsSpacing.lg, DsSpacing.lg),
              child: Row(
                children: [
                  _Stat(
                    label: 'Profit',
                    value: '\$${_format(revenue.totalProfit)}',
                  ),
                  _Divider(),
                  _Stat(
                    label: 'Margin',
                    value: '${revenue.profitMargin.toStringAsFixed(1)}%',
                  ),
                  _Divider(),
                  _Stat(
                    label: 'Orders',
                    value: '${revenue.totalOrders}',
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
      SellerRevenueData r, RevenuePeriod p) =>
      switch (p) {
        RevenuePeriod.today => (r.today, r.todayTrend),
        RevenuePeriod.week => (r.thisWeek, r.weekTrend),
        RevenuePeriod.month => (r.thisMonth, r.monthTrend),
        RevenuePeriod.year => (r.thisYear, r.yearTrend),
      };

  static String _format(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelect});

  final RevenuePeriod selected;
  final ValueChanged<RevenuePeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: DsRadius.borderSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: RevenuePeriod.values.map((p) {
          final active = p == selected;
          return GestureDetector(
            onTap: () => onSelect(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.xs, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: DsRadius.borderXs,
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: active
                      ? DsTypography.bold
                      : DsTypography.regular,
                  color: Colors.white
                      .withValues(alpha: active ? 1.0 : 0.65),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});

  final double trend;

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}% vs last period',
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: DsTypography.labelSmall,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: DsTypography.medium,
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
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.labelSmall,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}
