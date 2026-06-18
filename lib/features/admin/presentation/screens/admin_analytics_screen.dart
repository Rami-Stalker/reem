import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/providers/core_providers.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(analyticsDashboardProvider);
    final colors = context.dsColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Business intelligence',
            subtitle: 'Sales, revenue, conversion, cohorts, and live operations.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(analyticsDashboardProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Export PDF',
                onPressed: () => _export(context, ref, 'PDF'),
                icon: const Icon(Icons.picture_as_pdf_rounded),
              ),
              IconButton(
                tooltip: 'Export Excel',
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
                      style: TextStyle(color: colors.error),
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
          '$format report generated (${response.data?.length ?? 0} bytes).',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricGrid(data: data),
        const SizedBox(height: DsSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 980;
            final charts = [
              _Panel(
                title: 'Revenue trend',
                child: _BarSeries(points: data.salesSeries, valuePrefix: '\$'),
              ),
              _Panel(
                title: 'Conversion funnel',
                child: _BarSeries(points: data.funnel),
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
                title: 'Top products',
                child: _RankedList(items: data.topProducts),
              ),
              _Panel(
                title: 'Seller performance',
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
    final items = [
      _Metric('Gross revenue', '\$${data.grossRevenue.toStringAsFixed(0)}'),
      _Metric('Net revenue', '\$${data.netRevenue.toStringAsFixed(0)}'),
      _Metric('Orders', data.totalOrders.toString()),
      _Metric('AOV', '\$${data.averageOrderValue.toStringAsFixed(1)}'),
      _Metric('Customers', data.activeCustomers.toString()),
      _Metric('Repeat rate', '${data.repeatRate.toStringAsFixed(1)}%'),
      _Metric('Conversion', '${data.conversionRate.toStringAsFixed(1)}%'),
      _Metric('Online now', data.onlineUsers.toString()),
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
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DsTypography.headlineSmall,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
            ),
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
            style: TextStyle(
              fontSize: DsTypography.titleMedium,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BarSeries extends StatelessWidget {
  const _BarSeries({required this.points, this.valuePrefix = ''});

  final List<AnalyticsPoint> points;
  final String valuePrefix;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    if (points.isEmpty) {
      return Text('No data yet.', style: TextStyle(color: colors.onSurfaceVariant));
    }
    final maxValue = points.map((point) => point.value).reduce(
          (value, next) => value > next ? value : next,
        );
    return Column(
      children: [
        for (final point in points.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  child: Text(
                    point.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: DsRadius.borderFull,
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: maxValue == 0 ? 0 : point.value / maxValue,
                      backgroundColor: colors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                SizedBox(
                  width: 78,
                  child: Text(
                    '$valuePrefix${point.value.toStringAsFixed(0)}',
                    textAlign: TextAlign.end,
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
    final colors = context.dsColors;
    if (items.isEmpty) {
      return Text('No ranked data yet.', style: TextStyle(color: colors.onSurfaceVariant));
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
            trailing: Text('\$${entry.value.value.toStringAsFixed(0)}'),
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
    return Wrap(
      spacing: DsSpacing.sm,
      children: [
        for (final days in [7, 30, 90, 180])
          ChoiceChip(
            label: Text('${days}d'),
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
