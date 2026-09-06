import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_analytics/domain/entities/seller_analytics_report.dart';
import 'package:reem/features/seller_analytics/presentation/providers/seller_analytics_provider.dart';
import 'package:reem/features/seller_analytics/presentation/widgets/analytics_pieces.dart';
import 'package:reem/features/seller_analytics/presentation/widgets/analytics_trend_chart.dart';

/// The seller's analytics.
///
/// This tab used to be a grid of description cards — «تحليلات المبيعات: الإيراد،
/// متوسط قيمة الطلب، هامش الربح» — none of which opened anything. Meanwhile
/// `/analytics/*` had accepted the SELLER role and scoped every query to the
/// caller all along, and nothing in the app had ever called it.
///
/// The page answers four questions in the order a shopkeeper asks them: what
/// happened today, what did I earn, how many people who looked actually
/// bought, and who is buying.
class SellerAnalyticsScreen extends ConsumerWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerAnalyticsNotifierProvider);
    final notifier = ref.read(sellerAnalyticsNotifierProvider.notifier);
    final l10n = context.l10n;
    final report = state.report;

    return ReemScrollPage(
      onRefresh: notifier.refresh,
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        PremiumAppBar(title: l10n.sellerAnalytics),
        SliverToBoxAdapter(
          child: _PeriodBar(
            selected: state.period,
            onSelect: notifier.setPeriod,
          ),
        ),

        if (state.isInitialLoading)
          const SliverToBoxAdapter(child: _Skeleton())
        else if (report == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                message: state.error ?? l10n.analyticsFailed,
                onRetry: notifier.refresh,
              ),
            ),
          )
        else if (report.isEmpty)
          SliverToBoxAdapter(child: _EmptyWindow(period: state.period))
        else
          ..._report(context, report),

        DsGaps.sliverBottomSafe,
      ],
    );
  }

  List<Widget> _report(BuildContext context, SellerAnalyticsReport report) {
    final l10n = context.l10n;
    final palette = context.atelier;

    return [
      // ── Today ────────────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: AnalyticsSectionHeader(
          l10n.analyticsToday,
          hint: l10n.analyticsActiveCartsHint,
        ),
      ),
      SliverToBoxAdapter(
        child: AnalyticsMetricGrid(
          tiles: [
            AnalyticsMetricTile(
              label: l10n.analyticsTodayOrders,
              value: '${report.realtime.todayOrders}',
            ),
            AnalyticsMetricTile(
              label: l10n.sellerRevenue,
              amounts: report.realtime.todayRevenue,
              tone: palette.positive,
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsActiveCarts,
              value: '${report.realtime.activeCarts}',
            ),
          ],
        ),
      ),

      // ── Revenue ──────────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: AnalyticsSectionHeader(
          l10n.analyticsRevenueSection,
          hint: l10n.analyticsMultiCurrencyHint,
        ),
      ),
      SliverToBoxAdapter(
        child: AnalyticsMetricGrid(
          tiles: [
            AnalyticsMetricTile(
              label: l10n.analyticsGross,
              amounts: report.revenue.gross,
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsNet,
              amounts: report.revenue.net,
              tone: palette.positive,
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsCollected,
              amounts: report.revenue.paid,
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsRefunds,
              amounts: report.revenue.refunds,
              tone: report.revenue.refunds.isEmpty ? null : palette.critical,
            ),
          ],
        ),
      ),

      // ── Orders ───────────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: AnalyticsSectionHeader(l10n.analyticsOrdersSection),
      ),
      SliverToBoxAdapter(
        child: AnalyticsMetricGrid(
          tiles: [
            AnalyticsMetricTile(
              label: l10n.analyticsTotalOrders,
              value: '${report.sales.totalOrders}',
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsPaidOrders,
              value: '${report.sales.paidOrders}',
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsAverageOrder,
              amounts: report.sales.averageOrderValue,
            ),
          ],
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.md)),
      SliverToBoxAdapter(
        child: AnalyticsTrendChart(series: report.sales.series),
      ),

      // ── The path to a sale ───────────────────────────────────────────────
      SliverToBoxAdapter(
        child: AnalyticsSectionHeader(
          l10n.analyticsFunnel,
          hint: l10n.analyticsFunnelHint,
        ),
      ),
      SliverToBoxAdapter(
        child: AnalyticsFunnel(
          steps: report.funnel,
          labels: [
            l10n.sellerProductViews,
            l10n.sellerCartAdds,
            l10n.checkout,
            l10n.analyticsOrdersSection,
          ],
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.md)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: AnalyticsMetricTile(
            label: l10n.analyticsConversionOverall,
            value: '${report.conversion.overallRate}%',
            tone: palette.primary,
          ),
        ),
      ),

      // ── Customers ────────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: AnalyticsSectionHeader(l10n.analyticsCustomersSection),
      ),
      SliverToBoxAdapter(
        child: AnalyticsMetricGrid(
          tiles: [
            AnalyticsMetricTile(
              label: l10n.analyticsActiveCustomers,
              value: '${report.customers.activeCustomers}',
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsNewCustomers,
              value: '${report.customers.newCustomers}',
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsRepeatCustomers,
              value: '${report.customers.repeatCustomers}',
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsRepeatRate,
              value: '${report.customers.repeatRate}%',
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsAverageCustomer,
              amounts: report.customers.averageCustomerValue,
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsRetention7,
              value: '${report.retention.retained7d}',
              hint: '${report.retention.retention7dRate}%',
            ),
            AnalyticsMetricTile(
              label: l10n.analyticsRetention30,
              value: '${report.retention.retained30d}',
              hint: '${report.retention.retention30dRate}%',
            ),
          ],
        ),
      ),

      // ── Best sellers ─────────────────────────────────────────────────────
      if (report.topProducts.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: AnalyticsSectionHeader(l10n.analyticsTopProducts),
        ),
        SliverToBoxAdapter(
          child: AnalyticsProductTable(
            // Twenty rows is a data dump; the top ten is a page she reads.
            rows: report.topProducts.take(10).toList(growable: false),
          ),
        ),
      ],
    ];
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.selected, required this.onSelect});

  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    String label(AnalyticsPeriod period) => switch (period) {
      AnalyticsPeriod.week => l10n.analyticsPeriodWeek,
      AnalyticsPeriod.month => l10n.analyticsPeriodMonth,
      AnalyticsPeriod.quarter => l10n.analyticsPeriodQuarter,
      AnalyticsPeriod.year => l10n.analyticsPeriodYear,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          for (final period in AnalyticsPeriod.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpacing.sm),
              child: ChoiceChip(
                label: Text(label(period)),
                selected: selected == period,
                onSelected: (_) => onSelect(period),
                selectedColor: palette.primarySoft,
                backgroundColor: palette.surface,
                side: BorderSide(
                  color: selected == period ? palette.primary : palette.line,
                ),
                labelStyle: selected == period
                ? context.dsText.tab.bold.tint(palette.primary)
                : context.dsText.tab.medium.tint(palette.ink),
              ),
            ),
        ],
      ),
    );
  }
}

/// A window with nothing in it is not a failure — it is the honest answer for
/// a shop that opened last week, and it deserves a different sentence.
class _EmptyWindow extends StatelessWidget {
  const _EmptyWindow({required this.period});

  final AnalyticsPeriod period;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: DsRadius.borderXl,
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              Icons.insights_outlined,
              size: 36,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            l10n.analyticsEmpty,
            style: context.dsText.cardTitle.bold.tint(palette.ink),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            l10n.analyticsEmptyBlurb,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 96, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 96, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 220, borderRadius: DsRadius.lg),
          ],
        ),
      ),
    );
  }
}
