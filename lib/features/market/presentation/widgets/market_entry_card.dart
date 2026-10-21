import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';

/// The seller's way into phase four, from her dashboard.
///
/// One card, one live number: how many things the market is telling her right
/// now. The count is on the card because a seller should not have to open a
/// page to learn there is nothing to open it for — and when there is nothing,
/// the card says so plainly rather than showing a zero, because a zero beside
/// the word "فرص" reads as a failure of her shop rather than a quiet week.
class SellerMarketEntryCard extends ConsumerWidget {
  const SellerMarketEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final opportunities = ref.watch(sellerOpportunitiesProvider);
    final count = opportunities.asData?.value.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: InkWell(
          onTap: () => context.push(RoutePaths.sellerMarket),
          borderRadius: BorderRadius.circular(DsRadius.lg),
          child: Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 18,
                color: palette.primary,
              ),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.marketSellerTitle,
                      style: context.dsText.cardTitle.tint(palette.ink),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      opportunities.isLoading
                          ? context.l10n.marketReading
                          : count == 0
                          ? context.l10n.marketNoSignalShort
                          : context.l10n.marketOpportunityCount(count),
                      style: context.dsText.caption.tint(palette.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shopper's way into her wardrobe's life cycle, from the closet.
///
/// Renders nothing when there is nothing to say. A closet that needs no
/// attention should not carry a card announcing that — the absence *is* the
/// message, and a permanent tile saying «٠ قطع بدها انتباه» would make the
/// feature feel like an obligation.
class WardrobeCareEntryCard extends ConsumerWidget {
  const WardrobeCareEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final summary = ref.watch(wardrobeSummaryProvider).asData?.value;
    if (summary == null || summary.needsAttention == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: DsGlassCard(
        onTap: () => context.push(RoutePaths.marketWardrobe),
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          children: [
            Icon(Icons.spa_outlined, size: 18, color: colors.primary),
            DsGaps.hXs,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.marketCareTitle,
                    style: context.dsText.cardTitle.tint(colors.onSurface),
                  ),
                  DsGaps.vXxxs,
                  Text(
                    context.l10n.marketCareSummary(summary.needsAttention),
                    style: context.dsText.caption.tint(
                      colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
