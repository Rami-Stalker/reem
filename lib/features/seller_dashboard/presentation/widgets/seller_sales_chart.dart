import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_chart_data.dart';
import 'package:ohara/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_format.dart';
import 'package:ohara/features/seller_dashboard/presentation/widgets/seller_labels.dart';

/// The sales trend — revenue or orders over the chosen granularity.
///
/// Replaces a hand-rolled `CustomPainter` that could draw a line but had no
/// axes, no grid and nothing to touch: the seller could see a shape without
/// ever learning what any point was worth. This one is a real chart — labelled,
/// gridded, and readable by tapping a point.
///
/// Revenue and orders get their own toggle rather than sharing an axis. They
/// are quantities of different kinds and different magnitudes; overlaying them
/// on one scale would have flattened whichever lost the comparison.
class SellerSalesChart extends ConsumerStatefulWidget {
  const SellerSalesChart({super.key});

  @override
  ConsumerState<SellerSalesChart> createState() => _SellerSalesChartState();
}

enum _Metric { revenue, orders }

class _SellerSalesChartState extends ConsumerState<SellerSalesChart> {
  _Metric _metric = _Metric.revenue;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final notifier = ref.read(sellerDashboardNotifierProvider.notifier);
    final palette = context.atelier;
    final l10n = context.l10n;

    if (state.isInitialLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
          child: DsSkeleton.box(height: 244, borderRadius: DsRadius.xxl),
        ),
      );
    }

    final charts = state.data?.charts;
    if (charts == null || charts.isEmpty) return const SizedBox.shrink();

    final granularity = state.selectedChartPeriod;
    final dataset = charts[granularity] ?? charts.values.first;
    final points = _metric == _Metric.revenue
        ? dataset.revenuePoints
        : dataset.ordersPoints;
    if (points.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(DsRadius.xxl),
          border: Border.all(color: palette.line),
          boxShadow: palette.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sellerSalesTrend,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.tileTitle.bold.tint(palette.ink),
                  ),
                ),
                _MetricToggle(
                  selected: _metric,
                  onSelect: (m) => setState(() => _metric = m),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.sm),
            _GranularityTabs(
              selected: granularity,
              onSelect: notifier.setChartPeriod,
            ),
            const SizedBox(height: DsSpacing.md),
            SizedBox(
              height: 168,
              child: _Chart(points: points, metric: _metric),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.metric});

  final List<SellerChartPoint> points;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final line = metric == _Metric.revenue
        ? palette.series[0]
        : palette.series[1];

    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    // A flat series would otherwise collapse onto the axis; give it headroom
    // so a steady week still reads as a line rather than a rule.
    final ceiling = maxValue <= 0 ? 1.0 : maxValue * 1.18;

    final labelStyle = context.dsText.caption.tint(palette.muted);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: ceiling,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceiling / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: palette.line.withValues(alpha: 0.6),
            strokeWidth: 1,
            dashArray: const [4, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: ceiling / 3,
              getTitlesWidget: (value, meta) {
                if (value <= 0 || value >= ceiling) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: DsSpacing.xxs),
                  child: Text(
                    _axisLabel(value),
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                // Thin the labels on dense series so they never collide.
                final stride = (points.length / 6).ceil();
                if (stride > 1 && index % stride != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: DsSpacing.xs),
                  child: Text(points[index].label, style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => palette.ink.withValues(alpha: 0.92),
            tooltipBorderRadius: DsRadius.borderMd,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  _tooltipLabel(spot.y),
                  context.dsText.labelMedium.bold.tint(palette.background),
                ),
            ],
          ),
          getTouchedSpotIndicator: (barData, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: line.withValues(alpha: 0.4), strokeWidth: 1.5),
                FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4.5,
                    color: line,
                    strokeColor: palette.surface,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            curveSmoothness: 0.28,
            preventCurveOverShooting: true,
            barWidth: 2.6,
            color: line,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  line.withValues(alpha: 0.26),
                  line.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _axisLabel(double value) => metric == _Metric.revenue
      ? value.compactBare
      : formatCount(value.round());

  String _tooltipLabel(double value) => metric == _Metric.revenue
      ? value.sypFull
      : formatCount(value.round());
}

class _MetricToggle extends StatelessWidget {
  const _MetricToggle({required this.selected, required this.onSelect});

  final _Metric selected;
  final ValueChanged<_Metric> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final labels = {
      _Metric.revenue: l10n.sellerRevenue,
      _Metric.orders: l10n.orders,
    };

    return Container(
      padding: const EdgeInsets.all(DsSpacing.xxs),
      decoration: BoxDecoration(
        color: palette.primarySoft,
        borderRadius: DsRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final metric in _Metric.values)
            GestureDetector(
              onTap: () => onSelect(metric),
              child: AnimatedContainer(
                duration: DsMotion.fast,
                curve: DsMotion.silk,
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.xs,
                  vertical: DsSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: metric == selected
                      ? palette.primary
                      : Colors.transparent,
                  borderRadius: DsRadius.borderPill,
                ),
                child: Text(
                  labels[metric]!,
                  style: context.dsText.caption.bold.tint(metric == selected
                        ? palette.onPrimary
                        : palette.primary).copyWith(height: 1.1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GranularityTabs extends StatelessWidget {
  const _GranularityTabs({required this.selected, required this.onSelect});

  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Row(
      children: [
        for (final period in ChartPeriod.values) ...[
          if (period != ChartPeriod.values.first)
            const SizedBox(width: DsSpacing.xs),
          GestureDetector(
            onTap: () => onSelect(period),
            child: AnimatedContainer(
              duration: DsMotion.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.sm,
                vertical: DsSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: period == selected
                    ? palette.goldSoft
                    : Colors.transparent,
                borderRadius: DsRadius.borderPill,
                border: Border.all(
                  color: period == selected ? palette.gold : palette.line,
                ),
              ),
              child: Text(
                period.labelOf(l10n),
                style: context.dsText.caption.tint(period == selected ? palette.gold : palette.muted).copyWith(height: 1.1, fontWeight: period == selected
                      ? DsTypography.bold
                      : DsTypography.medium),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
