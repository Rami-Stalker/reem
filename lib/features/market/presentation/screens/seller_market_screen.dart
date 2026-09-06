import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';
import 'package:reem/features/seller_intelligence/presentation/widgets/intelligence_pieces.dart';

/// السوق — what is happening around her shop, and what to do about it.
///
/// Three sections in the order a morning goes: what the market is doing, what
/// is worth launching, and the launches she already has. The opportunities
/// lead because they are the only part that might change her plan; the drops
/// are underneath because they are work she has already decided to do.
///
/// Every opportunity here carries an action. That is enforced on the server —
/// a finding with nothing to do about it is dropped rather than shown — so
/// this screen never has to render an observation dressed as advice.
class SellerMarketScreen extends ConsumerWidget {
  const SellerMarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final opportunities = ref.watch(sellerOpportunitiesProvider);
    final candidates = ref.watch(dropCandidatesProvider);
    final drops = ref.watch(sellerDropsProvider);

    return ReemScrollPage(
      onRefresh: () async {
        ref
          ..invalidate(sellerOpportunitiesProvider)
          ..invalidate(dropCandidatesProvider)
          ..invalidate(sellerDropsProvider);
      },
      background: const SellerAtelierBackground(),
      backgroundColor: palette.background,
      slivers: [
        const PremiumAppBar(title: 'السوق'),

        const SectionTitle(
          title: 'فرص',
          subtitle: 'العرض مقابل الطلب بالأقسام اللي عم تبيعي فيها.',
        ),
        opportunities.when(
          loading: () => const _Loading(),
          error: (_, _) => const _Nothing(text: 'ما قدرنا نقرا السوق.'),
          data: (rows) => rows.isEmpty
              ? const _Nothing(
                  text:
                      'ما في إشارة قوية كفاية هلق. ريم ما بتحكي إلا لما يكون في بيانات تكفي.',
                )
              : SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
                  itemBuilder: (_, index) =>
                      _OpportunityTile(opportunity: rows[index]),
                ),
        ),

        const SectionTitle(
          title: 'يستاهل نزول',
          subtitle: 'منتجات عندك الطلب عليها أعلى من العادة.',
        ),
        candidates.when(
          loading: () => const _Loading(),
          error: (_, _) => const _Nothing(text: 'ما قدرنا نقرا المنتجات.'),
          data: (rows) => rows.isEmpty
              ? const _Nothing(
                  text: 'ما في منتج عندك بوضع يستاهل نزول خاص هلق.',
                )
              : SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
                  itemBuilder: (_, index) =>
                      _CandidateTile(candidate: rows[index]),
                ),
        ),

        const SectionTitle(title: 'نزولاتك'),
        drops.when(
          loading: () => const _Loading(),
          error: (_, _) => const _Nothing(text: 'ما قدرنا نجيب نزولاتك.'),
          data: (rows) => rows.isEmpty
              ? const _Nothing(text: 'لسا ما عملتي نزول.')
              : SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
                  itemBuilder: (_, index) => _DropTile(drop: rows[index]),
                ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xxl)),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: DsSpacing.xl),
      child: Center(child: DsLoadingIndicator()),
    ),
  );
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.sm,
        ),
        child: Text(text, style: context.dsText.caption.tint(palette.muted)),
      ),
    );
  }
}

/// One reading of the market, and the thing to do about it.
///
/// `SellerPanel`, not the buyer's glass card — the seller workspace has its
/// own surface and mixing the two would make one screen in her app look like
/// it belongs to a different product.
///
/// The confidence is shown as a word rather than a number. A seller does not
/// need to know it is 0.42; she needs to know whether to act on it now or
/// watch it for a week.
class _OpportunityTile extends StatelessWidget {
  const _OpportunityTile({required this.opportunity});

  final MarketOpportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final colour = switch (opportunity.code) {
      'SUPPLY_GAP' || 'STOCKED_OUT' => palette.primary,
      'CROWDED' || 'OVERSUPPLIED' || 'COOLING' => palette.caution,
      'WEAK_CONVERSION' => palette.critical,
      _ => palette.positive,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colour,
                    shape: BoxShape.circle,
                  ),
                ),
                DsGaps.hXs,
                Expanded(
                  child: Text(
                    opportunity.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.semibold.tint(palette.ink),
                  ),
                ),
                Text(
                  opportunity.confidence >= 0.6 ? 'مؤكّد' : 'مبدئي',
                  style: context.dsText.micro.tint(palette.muted),
                ),
              ],
            ),
            DsGaps.vXs,
            Text(
              opportunity.headline,
              style: context.dsText.body.tint(palette.ink),
            ),
            DsGaps.vXxs,
            Text(
              opportunity.action,
              style: context.dsText.caption.tint(colour),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate});

  final DropCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.tint(palette.ink),
                  ),
                  DsGaps.vXxs,
                  Text(
                    'الطلب ${candidate.demandScore.round()} · المخزون ${candidate.stockUnits}',
                    style: context.dsText.micro.tint(palette.muted),
                  ),
                ],
              ),
            ),
            DsGaps.hSm,
            IntelligenceDial(
              score: candidate.potential.toDouble(),
              size: 48,
              label: 'نزول',
            ),
          ],
        ),
      ),
    );
  }
}

class _DropTile extends StatelessWidget {
  const _DropTile({required this.drop});

  final Drop drop;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final statusAr = switch (drop.status) {
      'DRAFT' => 'مسوّدة',
      'SCHEDULED' => 'مجدول',
      'LIVE' => 'شغّال',
      'ENDED' => 'خلص',
      'CANCELLED' => 'ملغي',
      _ => drop.status,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drop.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.tint(palette.ink),
                  ),
                  DsGaps.vXxs,
                  Text(
                    '${drop.products.length} قطع · $statusAr',
                    style: context.dsText.micro.tint(palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
