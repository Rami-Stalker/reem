import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:ohara/features/admin/presentation/providers/admin_provider.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(analyticsDashboardProvider);
    final l10n = context.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminBusinessIntelligence,
            subtitle: l10n.adminAnalyticsSubtitle,
            icon: Icons.insights_rounded,
            highlights: [
              if (dashboard.value case final data?) ...[
                CourtHighlight(
                  value: data.grossRevenue.sypCompact,
                  label: l10n.adminGrossRevenue,
                ),
                CourtHighlight(
                  value: formatCount(data.totalOrders),
                  label: l10n.orders,
                ),
                CourtHighlight(
                  value: formatCount(data.onlineUsers),
                  label: l10n.adminOnlineNow,
                ),
              ],
            ],
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
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600
                  ? DsSpacing.md
                  : DsSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RangeSelector(
                  onSelected: (days) {
                    final end = DateTime.now();
                    ref
                        .read(analyticsDateRangeProvider.notifier)
                        .state = AnalyticsDateRange(
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
                  // The operator used to read `Exception: ` in front of the
                  // server's Arabic, with nothing to press afterwards.
                  error: (error, _) => CourtQuietNote(
                    icon: Icons.cloud_off_rounded,
                    color: context.console.critical,
                    message: messageOf(error),
                    action: SecondaryButton(
                      label: l10n.retry,
                      icon: Icons.refresh_rounded,
                      isExpanded: false,
                      onPressed: () =>
                          ref.invalidate(analyticsDashboardProvider),
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

  /// Fetches the report and hands the file to the system share sheet, so it
  /// can be saved, mailed or opened in a spreadsheet.
  ///
  /// It used to download the bytes and then announce "report ready" with the
  /// byte count presented as a row count — and keep the file nowhere. The
  /// operator had nothing to open.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    String format,
  ) async {
    final range = ref.read(analyticsDateRangeProvider);
    final dio = ref.read(dioProvider);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      final response = await dio.get<List<int>>(
        ApiEndpoints.analyticsExport,
        queryParameters: {
          'format': format,
          if (range.start != null) 'start_date': range.start!.toIso8601String(),
          if (range.end != null) 'end_date': range.end!.toIso8601String(),
        },
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data ?? const <int>[];
      final name = _fileName(
        // l10n-ignore: an HTTP header name
        response.headers.value('content-disposition'),
        format,
      );
      final directory = await getTemporaryDirectory();
      final file = File(p.join(directory.path, name));
      await file.writeAsBytes(bytes, flush: true);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, name: name)],
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      DsSnackbar.show(
        context,
        message: messageOf(error),
        type: DsSnackbarType.error,
      );
    }
  }

  /// The server's filename when it sent one, stamped with today's date so a
  /// second export does not overwrite the first in her downloads.
  static String _fileName(String? disposition, String format) {
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(disposition ?? '');
    final base =
        match?.group(1) ??
        switch (format) {
          // l10n-ignore: file names, not copy
          'EXCEL' => 'reem-analytics.xls',
          // l10n-ignore: file names, not copy
          'CSV' => 'reem-analytics.csv',
          // l10n-ignore: file names, not copy
          _ => 'reem-analytics.pdf',
        };
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final dot = base.lastIndexOf('.');
    return dot > 0
        ? '${base.substring(0, dot)}-$stamp${base.substring(dot)}'
        : '$base-$stamp';
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
    final series = context.console.series;
    final items = [
      (
        l10n.adminGrossRevenue,
        data.grossRevenue.sypCompact,
        Icons.payments_outlined,
      ),
      (
        l10n.adminNetRevenue,
        data.netRevenue.sypCompact,
        Icons.account_balance_wallet_outlined,
      ),
      (l10n.orders, formatCount(data.totalOrders), Icons.shopping_bag_outlined),
      (
        l10n.adminAov,
        data.averageOrderValue.sypCompact,
        Icons.receipt_outlined,
      ),
      (
        l10n.adminCustomers,
        formatCount(data.activeCustomers),
        Icons.people_alt_outlined,
      ),
      (
        l10n.adminRepeatRate,
        '${data.repeatRate.toStringAsFixed(1)}%',
        Icons.replay_rounded,
      ),
      (
        l10n.adminConversion,
        '${data.conversionRate.toStringAsFixed(1)}%',
        Icons.show_chart_rounded,
      ),
      (
        l10n.adminOnlineNow,
        formatCount(data.onlineUsers),
        Icons.wifi_tethering_rounded,
      ),
    ];
    // Measured tiles rather than a grid with a fixed aspect ratio: a figure
    // like «4.82 مليار ل.س» is wider than «284», and a fixed ratio is how a
    // tile ends up with its label pushed out of the bottom.
    return CourtFigureRow(
      children: [
        for (var i = 0; i < items.length; i++)
          CourtFigure(
            label: items[i].$1,
            value: items[i].$2,
            icon: items[i].$3,
            accent: series[(i ~/ 2) % series.length],
          ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => CourtPanel(title: title, child: child);
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
                    child: Text(
                      _axisDate(context, points[index].label),
                      style: labelStyle,
                    ),
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
                  child: DsMeter(
                    value: maxValue == 0 ? 0 : entry.value.value / maxValue,
                    weight: DsMeterWeight.bold,
                    color: palette.series[entry.key % palette.series.length],
                    track: palette.surfaceAlt,
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
    final ranked = items.take(8).toList(growable: false);
    final top = ranked
        .map((item) => item.value)
        .fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: [
        for (var i = 0; i < ranked.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: DsSizes.controlSm,
                  child: Text(
                    '${i + 1}',
                    style: context.dsText.metricSmall.displayFamily.tint(
                      i == 0 ? DsColors.gold500 : palette.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ranked[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.dsText.bodyStrong.tint(
                                palette.ink,
                              ),
                            ),
                          ),
                          DsGaps.hSm,
                          Text(
                            ranked[i].value.sypCompact,
                            style: context.dsText.labelStrong.tint(palette.ink),
                          ),
                        ],
                      ),
                      DsGaps.vXxs,
                      // Its share of the leader, as a silk thread.
                      ClipRRect(
                        borderRadius: DsRadius.borderPill,
                        child: LinearProgressIndicator(
                          value: top <= 0 ? 0 : ranked[i].value / top,
                          minHeight: DsSpacing.xxs,
                          backgroundColor: palette.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation(
                            i == 0 ? DsColors.gold400 : palette.primary,
                          ),
                        ),
                      ),
                      DsGaps.vXxs,
                      Text(
                        l10n.adminUnitsSold(ranked[i].units),
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final range = ref.watch(analyticsDateRangeProvider);
    // The chosen range is drawn as chosen: it never was, so every chip looked
    // equally unselected whichever window the figures were for.
    final days = range.start == null || range.end == null
        ? null
        : range.end!.difference(range.start!).inDays;
    return CourtFilterBeads<int>(
      selected: days,
      onSelected: (value) {
        if (value != null) onSelected(value);
      },
      options: [
        for (final d in const [7, 30, 90, 180])
          CourtFilterOption(value: d, label: l10n.adminLastDays(d)),
      ],
    );
  }
}

/// An axis date as «19 أكتوبر» rather than the `2026-10-19` the server keys
/// its points by. Anything that is not a date is shown as it came.
String _axisDate(BuildContext context, String label) {
  final date = DateTime.tryParse(label);
  if (date == null) return label;
  // l10n-ignore: an intl pattern; the locale supplies the words
  return formatCalendarDate(context.l10n, date, pattern: 'd MMM');
}
