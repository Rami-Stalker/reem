import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(analyticsDashboardProvider);
    final colors = context.dsColors;
    final l10n = context.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminBusinessIntelligence,
            subtitle: l10n.adminAnalyticsSubtitle,
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () => ref.invalidate(analyticsDashboardProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: l10n.adminExportPdf,
                onPressed: () => _export(context, ref, 'PDF'),
                icon: const Icon(Icons.picture_as_pdf_rounded),
              ),
              IconButton(
                tooltip: l10n.adminExportExcel,
                onPressed: () => _export(context, ref, 'EXCEL'),
                icon: const Icon(Icons.table_chart_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RangeSelector(
                  onSelected: (days) {
                    final end = DateTime.now();
                    ref.read(analyticsDateRangeProvider.notifier).state =
                        AnalyticsDateRange(
                      start: end.subtract(Duration(days: days)),
                      end: end,
                    );
                  },
                ),
                const SizedBox(height: DsSpacing.lg),
                dashboard.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(DsSpacing.xl),
                    child: Center(child: DsLoadingIndicator()),
                  ),
                  error: (error, _) => Container(
                    padding: const EdgeInsets.all(DsSpacing.xl),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: DsRadius.borderLg,
                      border: Border.all(
                        color: colors.error.withValues(alpha: .35),
                      ),
                    ),
                    child: Text(
                      error.toString(),
                      style: context.dsText.body.tint(colors.error),
                    ),
                  ),
                  data: (data) => _Dashboard(data: data),
                ),
                const SizedBox(height: DsSpacing.xxxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    String format,
  ) async {
    final range = ref.read(analyticsDateRangeProvider);
    final dio = ref.read(dioProvider);
    final response = await dio.get<List<int>>(
      ApiEndpoints.analyticsExport,
      queryParameters: {
        'format': format,
        if (range.start != null) 'start_date': range.start!.toIso8601String(),
        if (range.end != null) 'end_date': range.end!.toIso8601String(),
      },
      options: Options(responseType: ResponseType.bytes),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.adminReportGenerated(
            format,
            response.data?.length ?? 0,
          ),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data});

  final AnalyticsDashboardEntity data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricGrid(data: data),
        const SizedBox(height: DsSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 980;
            final charts = [
              // Revenue over time is a trend, so it gets a line. The
              // funnel is a set of ranked steps, so it keeps its bars. Both
              // used the same bar widget before, which drew a time series as
              // an unordered ranking.
              _Panel(
                title: l10n.adminRevenueTrend,
                child: _TrendChart(points: data.salesSeries),
              ),
              _Panel(
                title: l10n.adminConversionFunnel,
                child: _FunnelBars(points: data.funnel),
              ),
            ];
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[0]),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(child: charts[1]),
                    ],
                  )
                : Column(
                    children: [
                      charts[0],
                      const SizedBox(height: DsSpacing.md),
                      charts[1],
                    ],
                  );
          },
        ),
        const SizedBox(height: DsSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 980;
            final lists = [
              _Panel(
                title: l10n.adminTopProducts,
                child: _RankedList(items: data.topProducts),
              ),
              _Panel(
                title: l10n.adminSellerPerformance,
                child: _RankedList(items: data.topSellers),
              ),
            ];
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: lists[0]),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(child: lists[1]),
                    ],
                  )
                : Column(
                    children: [
                      lists[0],
                      const SizedBox(height: DsSpacing.md),
                      lists[1],
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data});

  final AnalyticsDashboardEntity data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      _Metric(l10n.adminGrossRevenue, data.grossRevenue.sypCompact),
      _Metric(l10n.adminNetRevenue, data.netRevenue.sypCompact),
      _Metric(l10n.orders, formatCount(data.totalOrders)),
      _Metric(l10n.adminAov, data.averageOrderValue.sypCompact),
      _Metric(l10n.adminCustomers, formatCount(data.activeCustomers)),
      _Metric(l10n.adminRepeatRate, '${data.repeatRate.toStringAsFixed(1)}%'),
      _Metric(l10n.adminConversion, '${data.conversionRate.toStringAsFixed(1)}%'),
      _Metric(l10n.adminOnlineNow, formatCount(data.onlineUsers)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 720
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: DsSpacing.md,
          crossAxisSpacing: DsSpacing.md,
          childAspectRatio: 2.3,
          children: items.map((item) => _MetricCard(item: item)).toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _Metric item;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.screenTitle.bold.tint(colors.onSurface),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.dsText.cardTitle.bold.tint(colors.onSurface),
          ),
          const SizedBox(height: DsSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Revenue over the selected range, as an area line.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<AnalyticsPoint> points;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;

    if (points.isEmpty) {
      return Text(
        l10n.adminNoDataYet,
        style: context.dsText.body.tint(palette.muted),
      );
    }

    final line = palette.series.first;
    final maxValue = points
        .map((point) => point.value)
        .reduce((value, next) => value > next ? value : next);
    // Headroom, so a flat range still reads as a line rather than a rule.
    final ceiling = maxValue <= 0 ? 1.0 : maxValue * 1.18;

    final labelStyle = context.dsText.caption.tint(palette.muted);

    return SizedBox(
      height: 220,
      child: LineChart(
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
                reservedSize: 46,
                interval: ceiling / 3,
                getTitlesWidget: (value, meta) {
                  if (value <= 0 || value >= ceiling) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: DsSpacing.xxs,
                    ),
                    child: Text(
                      value.compactBare,
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
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  // Thin the labels on a long range so they never collide.
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
                    spot.y.sypFull,
                    context.dsText.labelMedium.bold.tint(palette.background),
                  ),
              ],
            ),
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
      ),
    );
  }
}

/// The conversion funnel: ranked steps, each a share of the widest.
class _FunnelBars extends StatelessWidget {
  const _FunnelBars({required this.points});

  final List<AnalyticsPoint> points;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;

    if (points.isEmpty) {
      return Text(
        l10n.adminNoDataYet,
        style: context.dsText.body.tint(palette.muted),
      );
    }

    final maxValue = points
        .map((point) => point.value)
        .reduce((value, next) => value > next ? value : next);

    return Column(
      children: [
        for (final entry in points.take(10).toList().asMap().entries)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  child: Text(
                    entry.value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.tint(palette.ink),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: DsRadius.borderFull,
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: maxValue == 0 ? 0 : entry.value.value / maxValue,
                      backgroundColor: palette.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation(
                        palette.series[entry.key % palette.series.length],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatCount(entry.value.value.round()),
                    textAlign: TextAlign.end,
                    style: context.dsText.body.semibold.tint(palette.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RankedList extends StatelessWidget {
  const _RankedList({required this.items});

  final List<AnalyticsRankedItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    if (items.isEmpty) {
      return Text(
        l10n.adminNoRankedData,
        style: context.dsText.body.tint(palette.muted),
      );
    }
    return Column(
      children: [
        for (final entry in items.take(8).toList().asMap().entries)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text('${entry.key + 1}'),
            ),
            title: Text(entry.value.title),
            subtitle: Text(entry.value.subtitle),
            trailing: Text(entry.value.value.sypCompact),
          ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: DsSpacing.sm,
      children: [
        for (final days in [7, 30, 90, 180])
          ChoiceChip(
            label: Text(l10n.adminLastDays(days)),
            selected: false,
            onSelected: (_) => onSelected(days),
          ),
      ],
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}
