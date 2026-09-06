import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';
import 'package:reem/features/market/presentation/widgets/market_pieces.dart';

/// سوق المستعمل — a separate room, on purpose.
///
/// A used dress and a boutique's new one answer different questions, and
/// putting them in the same grid degrades both: the boutique loses the frame
/// that justifies its price, and the used piece loses the context that makes
/// its price a bargain rather than a discount. So this has its own screen and
/// never appears in product search.
///
/// Every card leads with two facts a second-hand marketplace normally hides:
/// how much it saves against the original, and how many times it was worn.
class ResaleMarketScreen extends ConsumerStatefulWidget {
  const ResaleMarketScreen({super.key});

  @override
  ConsumerState<ResaleMarketScreen> createState() => _ResaleMarketScreenState();
}

class _ResaleMarketScreenState extends ConsumerState<ResaleMarketScreen> {
  bool _mine = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final market = ref.watch(resaleMarketProvider(null));
    final mine = ref.watch(myListingsProvider);
    final async = _mine ? mine : market;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const ReemAppBar(title: 'سوق المستعمل'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.lg,
              vertical: DsSpacing.sm,
            ),
            child: Row(
              children: [
                DsChip(
                  label: 'المعروض',
                  selected: !_mine,
                  onTap: () => setState(() => _mine = false),
                ),
                DsGaps.hXs,
                DsChip(
                  label: 'عروضي',
                  selected: _mine,
                  onTap: () => setState(() => _mine = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: DsLoadingIndicator()),
              error: (_, _) => DsErrorState(
                message: 'ما قدرنا نجيب العروض.',
                onRetry: () => ref
                  ..invalidate(resaleMarketProvider(null))
                  ..invalidate(myListingsProvider),
              ),
              data: (listings) => listings.isEmpty
                  ? DsEmptyState(
                      icon: Icons.storefront_outlined,
                      title: _mine ? 'ما عندك عروض' : 'ما في شي معروض هلق',
                      message: _mine
                          ? 'لما ريم تلاقي قطعة واقفة بخزانتك، بتقترح عليكِ تعرضيها هون.'
                          : 'السوق بيتعبّى من خزانات البنات. رجعي بعدين.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref
                        ..invalidate(resaleMarketProvider(null))
                        ..invalidate(myListingsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(DsSpacing.lg),
                        itemCount: listings.length,
                        separatorBuilder: (_, _) => DsGaps.vSm,
                        itemBuilder: (_, index) => _ListingCard(
                          listing: listings[index],
                          owned: _mine,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing, required this.owned});

  final ResaleListing listing;
  final bool owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;

    return DsGlassCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketThumb(imageUrl: listing.imageUrl, size: 64),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.tint(colors.onSurface),
                      ),
                    ),
                    if (listing.savingPercent != null)
                      DsBadge(
                        label: '-${listing.savingPercent}%',
                        tone: DsBadgeTone.sale,
                      ),
                  ],
                ),
                DsGaps.vXxs,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      sypText(listing.priceSyp),
                      style: DsTypography.price(
                        colors.price,
                        size: DsTypography.bodySmall,
                      ),
                    ),
                    if (listing.originalPriceSyp != null) ...[
                      DsGaps.hXs,
                      Text(
                        sypText(listing.originalPriceSyp),
                        style: DsTypography.priceStrike(
                          colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                DsGaps.vXxs,
                Text(
                  [
                    listing.conditionAr,
                    if (listing.wearCount != null)
                      'انلبست ${listing.wearCount} مرات',
                    if (listing.slotLabel != null) listing.slotLabel!,
                    if (!owned && listing.sellerName != null)
                      'من ${listing.sellerName}',
                  ].join(' · '),
                  style: context.dsText.micro.tint(colors.onSurfaceVariant),
                ),
                if (owned) ...[
                  DsGaps.vXs,
                  _OwnerActions(listing: listing),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Publishing is a second, deliberate decision.
///
/// Drafting a listing showed her what a piece is worth; this is where she
/// chooses to offer it to strangers. Keeping them apart is the whole reason
/// the draft state exists.
class _OwnerActions extends ConsumerWidget {
  const _OwnerActions({required this.listing});

  final ResaleListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = switch (listing.status) {
      'DRAFT' => ('انشريها', 'LISTED'),
      'WITHDRAWN' => ('ارجعي انشريها', 'LISTED'),
      'LISTED' => ('سحبيها', 'WITHDRAWN'),
      'RESERVED' => ('انباعت', 'SOLD'),
      _ => null,
    };
    if (next == null) {
      return Text(
        'انباعت',
        style: context.dsText.micro.tint(context.dsColors.success),
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DsButton(
        label: next.$1,
        size: DsButtonSize.sm,
        isExpanded: false,
        variant: DsButtonVariant.secondary,
        onPressed: () async {
          final result = await ref
              .read(marketRepositoryProvider)
              .setListingStatus(listing.id, next.$2);
          if (!context.mounted) return;
          result.fold(
            (failure) => DsSnackbar.error(context, failure.message),
            (_) => ref
              ..invalidate(myListingsProvider)
              ..invalidate(resaleMarketProvider(null))
              ..invalidate(wardrobeAttentionProvider),
          );
        },
      ),
    );
  }
}
