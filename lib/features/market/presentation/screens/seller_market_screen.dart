import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/market/domain/entities/market.dart';
import 'package:ohara/features/market/presentation/providers/market_providers.dart';
import 'package:ohara/features/seller_intelligence/presentation/widgets/intelligence_pieces.dart';

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

    return OharaScrollPage(
      onRefresh: () async {
        ref
          ..invalidate(sellerOpportunitiesProvider)
          ..invalidate(dropCandidatesProvider)
          ..invalidate(sellerDropsProvider);
      },
      background: const SellerAtelierBackground(),
      backgroundColor: palette.background,
      slivers: [
        PremiumAppBar(title: context.l10n.marketSellerTitle),

        SectionTitle(
          title: context.l10n.marketOpportunities,
          subtitle: context.l10n.marketOpportunitiesBody,
        ),
        opportunities.when(
          loading: () => const _Loading(),
          error: (_, _) => _Nothing(text: context.l10n.marketReadFailed),
          data: (rows) => rows.isEmpty
              ? _Nothing(text: context.l10n.marketNoSignal)
              : SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
                  itemBuilder: (_, index) =>
                      _OpportunityTile(opportunity: rows[index]),
                ),
        ),

        SectionTitle(
          title: context.l10n.marketWorthADrop,
          subtitle: context.l10n.marketWorthADropBody,
        ),
        candidates.when(
          loading: () => const _Loading(),
          error: (_, _) => _Nothing(text: context.l10n.marketProductsFailed),
          data: (rows) => rows.isEmpty
              ? _Nothing(text: context.l10n.marketNoDropCandidates)
              : SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
                  itemBuilder: (_, index) =>
                      _CandidateTile(candidate: rows[index]),
                ),
        ),

        SectionTitle(title: context.l10n.marketYourDrops),
        drops.when(
          loading: () => const _Loading(),
          error: (_, _) => _Nothing(text: context.l10n.marketYourDropsFailed),
          data: (rows) => rows.isEmpty
              ? _Nothing(text: context.l10n.marketNoOwnDrops)
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
                  opportunity.confidence >= 0.6
                      ? context.l10n.marketConfidenceHigh
                      : context.l10n.marketConfidenceLow,
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
                    context.l10n.marketCandidateStats(
                      candidate.demandScore.round(),
                      candidate.stockUnits,
                    ),
                    style: context.dsText.micro.tint(palette.muted),
                  ),
                ],
              ),
            ),
            DsGaps.hSm,
            IntelligenceDial(
              score: candidate.potential.toDouble(),
              size: 48,
              label: context.l10n.marketDropAction,
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
      'DRAFT' => context.l10n.marketDropDraft,
      'SCHEDULED' => context.l10n.marketDropScheduled,
      'LIVE' => context.l10n.marketDropLive,
      'ENDED' => context.l10n.marketDropEnded,
      'CANCELLED' => context.l10n.marketDropCancelled,
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
                    context.l10n.marketDropSummary(
                      drop.products.length,
                      statusAr,
                    ),
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
