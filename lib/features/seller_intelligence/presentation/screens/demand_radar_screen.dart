import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';
import 'package:reem/features/seller_intelligence/presentation/providers/intelligence_providers.dart';
import 'package:reem/features/seller_intelligence/presentation/widgets/intelligence_pieces.dart';

/// رادار الطلب — what the market is asking for, read for her shop.
///
/// The page opens on **one ordered list of things to do** and keeps the
/// evidence underneath it. That ordering is the whole argument: a seller does
/// not want four ranked lists and the job of deciding which to read first,
/// she wants to know what to do this morning. The rising categories, the
/// unserved searches and the price movements are all still here, below, for
/// when she wants to see where a recommendation came from.
///
/// Everything on this page is read from the trend engine's nightly tables.
/// Nothing is estimated, and when there is no signal the page says so rather
/// than drawing an empty chart.
class DemandRadarScreen extends ConsumerWidget {
  const DemandRadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final async = ref.watch(demandRadarProvider);

    return ReemScrollPage(
      onRefresh: () async => ref.invalidate(demandRadarProvider),
      background: const SellerAtelierBackground(),
      backgroundColor: palette.background,
      slivers: [
        const PremiumAppBar(title: 'رادار الطلب'),
        ...async.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            ),
          ],
          error: (_, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsErrorState(
                  message: 'ما قدرنا نجيب بيانات الرادار.',
                  onRetry: () => ref.invalidate(demandRadarProvider),
                ),
              ),
            ),
          ],
          data: (radar) => _body(context, radar),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xxl)),
      ],
    );
  }

  List<Widget> _body(BuildContext context, DemandRadar radar) {
    if (radar.hasNoListings) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(DsSpacing.lg),
            child: DsEmptyState(
              icon: Icons.radar_rounded,
              title: 'ما في منتجات بعد',
              // The radar reads the market against what she sells. With no
              // listings there is nothing to read it against, and saying that
              // is more useful than an empty chart.
              message: 'ضيفي أول منتج ومنبلّش نقرالك السوق.',
            ),
          ),
        ),
      ];
    }

    if (radar.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(DsSpacing.lg),
            child: DsEmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'لسا عم نجمع البيانات',
              message: 'الرادار بيقرا حركة السوق كل ليلة. ارجعي بكرا.',
            ),
          ),
        ),
      ];
    }

    return [
      if (radar.opportunities.isNotEmpty) ...[
        const SectionTitle(
          title: 'شو أعمل هلق',
          subtitle: 'مرتّبة حسب الأهم لمتجرك',
        ),
        SliverList.builder(
          itemCount: radar.opportunities.length.clamp(0, 6),
          itemBuilder: (context, i) =>
              _OpportunityCard(opportunity: radar.opportunities[i]),
        ),
      ],

      if (radar.stockAlerts.isNotEmpty) ...[
        const SectionTitle(
          title: 'المخزون تحت الطلب',
          subtitle: 'قطع الطلب عليها ماشي والكمية عم تخلص',
        ),
        SliverList.builder(
          itemCount: radar.stockAlerts.length,
          itemBuilder: (context, i) => _StockCard(alert: radar.stockAlerts[i]),
        ),
      ],

      if (radar.rising.isNotEmpty) ...[
        const SectionTitle(
          title: 'فئات صاعدة',
          subtitle: 'الطلب عليها عم يزيد',
        ),
        SliverToBoxAdapter(child: _RisingRow(rows: radar.rising)),
      ],

      if (radar.unmet.isNotEmpty) ...[
        const SectionTitle(
          title: 'طلب ما لقى جوابه',
          subtitle: 'بنات دوّروا وما لقوا شي مناسب',
        ),
        SliverList.builder(
          itemCount: radar.unmet.length,
          itemBuilder: (context, i) => _UnmetCard(term: radar.unmet[i]),
        ),
      ],

      if (radar.priceTrends.isNotEmpty) ...[
        const SectionTitle(title: 'حركة الأسعار'),
        SliverList.builder(
          itemCount: radar.priceTrends.length,
          itemBuilder: (context, i) => _PriceCard(trend: radar.priceTrends[i]),
        ),
      ],
    ];
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final (icon, colour) = switch (opportunity.kind) {
      OpportunityKind.restock => (Icons.inventory_2_rounded, palette.critical),
      OpportunityKind.unmetInCategory => (Icons.search_off_rounded, palette.gold),
      OpportunityKind.risingCategory => (Icons.trending_up_rounded, palette.positive),
      OpportunityKind.enterCategory => (Icons.explore_rounded, palette.primary),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(DsSpacing.sm),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.12),
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, size: 20, color: colour),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Text(
                opportunity.ar,
                style: context.dsText.body.tint(palette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.alert});

  final StockAlert alert;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final colour = severityColor(context, alert.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.ar, style: context.dsText.body.tint(palette.ink)),
            const SizedBox(height: DsSpacing.xs),
            Row(
              children: [
                Icon(Icons.inventory_rounded, size: 14, color: colour),
                DsGaps.hXxs,
                Text(
                  alert.stockUnits == 0
                      ? 'ما ضل ولا قطعة'
                      : 'باقي ${alert.stockUnits} قطعة',
                  style: context.dsText.caption.tint(colour),
                ),
                if (alert.coverDays != null && alert.coverDays! > 0) ...[
                  const SizedBox(width: DsSpacing.sm),
                  Text(
                    'تكفّي ${alert.coverDays!.round()} يوم',
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The rising categories, laid out horizontally.
///
/// Horizontal because they are alternatives to scan, not a ranked list to work
/// down — and because the difference between one she sells in and one she does
/// not is the thing worth noticing, which reads better side by side.
class _RisingRow extends StatelessWidget {
  const _RisingRow({required this.rows});

  final List<RisingCategory> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
        itemBuilder: (context, i) {
          final row = rows[i];
          return SizedBox(
            width: 168,
            child: SellerPanel(
              padding: const EdgeInsets.all(DsSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.semibold.tint(palette.ink),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 15,
                        color: palette.positive,
                      ),
                      DsGaps.hXxs,
                      Text(
                        '+${row.growthPercent}%',
                        style: context.dsText.body.semibold.tint(
                          palette.positive,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    row.isSelling ? 'عم تبيعي فيها' : 'ما عندك شي فيها',
                    style: context.dsText.micro.tint(
                      row.isSelling ? palette.primary : palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UnmetCard extends StatelessWidget {
  const _UnmetCard({required this.term});

  final UnmetDemand term;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '«${term.display}»',
                    style: context.dsText.body.semibold.tint(palette.ink),
                  ),
                  DsGaps.vXxxs,
                  Text(
                    '${term.searches} بحث · ${(term.missRate * 100).round()}% ما لقوا شي',
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                ],
              ),
            ),
            if (term.inHerCategories)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: palette.goldSoft,
                  borderRadius: BorderRadius.circular(DsRadius.pill),
                ),
                child: Text(
                  'بفئتك',
                  style: context.dsText.micro.tint(palette.gold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.trend});

  final PriceTrend trend;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final colour = trend.isRising
        ? palette.positive
        : trend.isFalling
        ? palette.caution
        : palette.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          children: [
            Icon(
              trend.isRising
                  ? Icons.north_east_rounded
                  : trend.isFalling
                  ? Icons.south_east_rounded
                  : Icons.remove_rounded,
              size: 16,
              color: colour,
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Text(
                trend.ar,
                style: context.dsText.caption.tint(palette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
