import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/discovery/domain/entities/product_collection.dart';
import 'package:reem/features/home/domain/entities/flash_deal.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';

/// Flash deals — a horizontal rail of time-boxed, limited-quantity offers, each
/// with a live countdown and a "claimed" stock meter that turns urgent as it
/// fills. The hero of the home page's sale energy.
class HomeFlashDeals extends ConsumerWidget {
  const HomeFlashDeals({super.key});

  static const double _cardWidth = 174;
  static const double _railHeight = 296;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final deals = ref.watch(
      homeContentNotifierProvider
          .select((s) => s.content?.flashDeals ?? const <FlashDeal>[]),
    );

    if (!isLoading && deals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          eyebrow: '⚡ Limited time',
          title: context.l10n.homeFlashDeals,
          onSeeAll: () =>
              context.push(RoutePaths.collectionOf(ProductCollection.bestSelling.key)),
        ),
        SizedBox(
          height: _railHeight,
          child: isLoading
              ? _skeleton(context)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: deals.length,
                  separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
                  itemBuilder: (context, i) => SizedBox(
                    width: _cardWidth,
                    child: _FlashDealCard(deal: deals[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (_, _) => SizedBox(
          width: _cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DsSkeleton.box(height: 174, borderRadius: DsRadius.lg),
              const SizedBox(height: DsSpacing.sm),
              DsSkeleton.line(width: 140),
              const SizedBox(height: DsSpacing.xs),
              DsSkeleton.line(width: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlashDealCard extends StatelessWidget {
  const _FlashDealCard({required this.deal});

  final FlashDeal deal;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final product = deal.product;
    final urgent = deal.isAlmostGone;
    final meterColor = urgent ? c.discount : c.primary;

    return GestureDetector(
      onTap: () => context.push('${RoutePaths.productDetails}?id=${product.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: DsRadius.borderLg,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: product.coverUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                    errorWidget: (_, _, _) =>
                        ColoredBox(color: c.surfaceVariant),
                  ),
                ),
                if (product.hasDiscount)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.discount,
                        borderRadius: DsRadius.borderFull,
                      ),
                      child: Text(
                        '−${product.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: DsTypography.bold,
                        ),
                      ),
                    ),
                  ),
                // Live countdown on a glass pill.
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.xs, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: DsRadius.borderFull,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            size: 14, color: Colors.white),
                        if (deal.endsAt != null) ...[
                          const SizedBox(width: 4),
                          DsCountdownTimer(
                            endsAt: deal.endsAt!,
                            compact: true,
                            boxColor: Colors.white.withValues(alpha: 0.18),
                            foreground: Colors.white,
                            separatorColor: Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.semiBold,
              fontSize: DsTypography.bodySmall,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          // Both prices are unbounded text in a fixed-width deal card, which
          // overflowed the moment the figures became real SYP amounts
          // («850,000 ل.س» beside a struck «1,440,000 ل.س»). The live price
          // gets the larger share; the was-price gives way first.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                flex: 3,
                child: Text(
                  product.price?.format() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.price(
                    c.price,
                    size: DsTypography.titleSmall,
                  ),
                ),
              ),
              if (product.hasDiscount) ...[
                const SizedBox(width: 4),
                Flexible(
                  flex: 2,
                  child: Text(
                    product.compareAtPrice?.format(includeSymbol: false) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.priceStrike(c.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          // Claimed stock meter.
          ClipRRect(
            borderRadius: DsRadius.borderFull,
            child: Stack(
              children: [
                Container(height: 6, color: c.onSurface.withValues(alpha: 0.08)),
                FractionallySizedBox(
                  widthFactor: deal.claimedFraction,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: meterColor,
                      borderRadius: DsRadius.borderFull,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            urgent
                ? 'Almost gone — ${deal.remainingQuantity} left'
                : '${deal.soldCount} claimed',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.labelSmall,
              fontWeight: urgent ? DsTypography.bold : DsTypography.medium,
              color: urgent ? c.discount : c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
