import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_analytics/domain/entities/seller_analytics_report.dart';

enum TrendMetric { revenue, orders }

/// Revenue or orders across the chosen window.
///
/// The two metrics get a toggle rather than a shared axis: they are quantities
/// of different kinds and wildly different magnitudes, and overlaying them
/// would flatten whichever lost the comparison into a straight line along the
/// bottom. The same choice the dashboard's chart makes, for the same reason.
class AnalyticsTrendChart extends StatefulWidget {
  const AnalyticsTrendChart({super.key, required this.series});

  final List<SalesSeriesPoint> series;

  @override
  State<AnalyticsTrendChart> createState() => _AnalyticsTrendChartState();
}

class _AnalyticsTrendChartState extends State<AnalyticsTrendChart> {
  TrendMetric _metric = TrendMetric.revenue;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final series = widget.series;

    if (series.length < 2) return const SizedBox.shrink();

    final values = [
      for (final point in series)
        _metric == TrendMetric.revenue
            ? point.plottableRevenue
            : point.orders.toDouble(),
    ];
    final peak = values.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
      child: SellerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: AtelierHeading(title: l10n.analyticsTrend)),
                _Toggle(
                  selected: _metric,
                  onSelect: (metric) => setState(() => _metric = metric),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  // A flat series would otherwise collapse onto the axis.
                  maxY: peak <= 0 ? 1 : peak * 1.15,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    // Pattern paper: dotted rules rather than solid ones.
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: palette.line,
                      strokeWidth: 1,
                      dashArray: const [2, 5],
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
                        getTitlesWidget: (value, meta) => Text(
                          _compact(value),
                          style: context.dsText.micro.tint(palette.muted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        // Six labels at most: a ninety-day window would
                        // otherwise print a solid black bar of dates.
                        interval: (series.length / 6).ceilToDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= series.length) {
                            return const SizedBox.shrink();
                          }
                          final date = series[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: DsSpacing.xs),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: context.dsText.micro.tint(palette.muted),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => palette.raised,
                      // One tooltip per point, not one per thread.
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          spot.barIndex == 0
                              ? LineTooltipItem(
                                  _tooltipFor(series[spot.x.round()]),
                                  context.dsText.caption.tint(palette.ink),
                                )
                              : null,
                      ],
                    ),
                  ),
                  // The takings sewn as thread: a plum line with a champagne
                  // running stitch over it, and a gold knot on the latest
                  // point.
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      curveSmoothness: 0.28,
                      barWidth: 3,
                      color: palette.primary,
                      dotData: FlDotData(
                        checkToShowDot: (spot, _) =>
                            spot.x.round() == values.length - 1,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 6,
                              color: palette.surface,
                              strokeWidth: 2.5,
                              strokeColor: palette.gold,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            palette.primary.withValues(alpha: 0.2),
                            palette.primary.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      spots: [
                        for (var i = 0; i < values.length; i++)
                          FlSpot(i.toDouble(), values[i]),
                      ],
                    ),
                    LineChartBarData(
                      isCurved: true,
                      curveSmoothness: 0.28,
                      barWidth: 1.4,
                      color: DsColors.gold100,
                      dashArray: const [5, 5],
                      dotData: const FlDotData(show: false),
                      spots: [
                        for (var i = 0; i < values.length; i++)
                          FlSpot(i.toDouble(), values[i]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tooltipFor(SalesSeriesPoint point) {
    final date = '${point.date.day}/${point.date.month}';
    if (_metric == TrendMetric.orders) return '$date · ${point.orders}';
    return point.revenue.isEmpty
        ? '$date · —'
        : '$date · ${point.revenue.first.format()}';
  }

  /// Axis labels only, so an approximation is the honest thing here — a full
  /// SYP figure would be eight digits wide and unreadable at 10pt.
  String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.selected, required this.onSelect});

  final TrendMetric selected;
  final ValueChanged<TrendMetric> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.xxs),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final metric in TrendMetric.values)
            GestureDetector(
              onTap: () => onSelect(metric),
              child: AnimatedContainer(
                duration: DsMotion.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm + DsSpacing.xxxs,
                  vertical: DsSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: selected == metric ? palette.primary : null,
                  borderRadius: DsRadius.borderPill,
                ),
                child: Text(
                  metric == TrendMetric.revenue
                      ? l10n.analyticsTrendRevenue
                      : l10n.analyticsTrendOrders,
                  style: context.dsText.caption.semibold.tint(
                    selected == metric ? DsColors.onMedia : palette.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
