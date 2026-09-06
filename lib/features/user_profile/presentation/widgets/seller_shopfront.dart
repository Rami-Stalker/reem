import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:reem/features/reputation/presentation/widgets/review_card.dart';
import 'package:reem/features/reputation/presentation/widgets/review_composer.dart';

/// What a boutique's profile is actually for.
///
/// The page opened on a name, a follow button and a stats card, and stopped —
/// no pieces, no reviews, no way to say anything about the shop. All three
/// providers behind this existed and had zero consumers: `sellerProducts`,
/// `sellerReviews` and `sellerReputation` were written, wired to real
/// endpoints, and read by nothing. So a shopper could reach a boutique from a
/// product card and learn less about it there than on the card she came from.
class SellerShopfront extends StatelessWidget {
  const SellerShopfront({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.isMe,
  });

  final String sellerId;
  final String sellerName;

  /// Her own shop: she manages it elsewhere, and cannot review herself.
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DsSpacing.xl),
        _SellerProducts(sellerId: sellerId, sellerName: sellerName),
        const SizedBox(height: DsSpacing.xl),
        _SellerReviews(sellerId: sellerId, isMe: isMe),
      ],
    );
  }
}

/// A rail of her pieces, with the whole shelf a tap away.
class _SellerProducts extends ConsumerWidget {
  const _SellerProducts({required this.sellerId, required this.sellerName});

  final String sellerId;
  final String sellerName;

  static const _previewCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerProductsProvider(sellerId));
    final products = state.items.take(_previewCount).toList(growable: false);

    if (state.isLoading && products.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: DsLoadingIndicator()),
      );
    }
    // A shop whose shelf would not load says so. Rendering nothing here would
    // read as "she sells nothing", which is a different and worse claim.
    if (products.isEmpty && state.error != null) {
      return DsErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(sellerProductsProvider(sellerId).notifier).refresh(),
      );
    }
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.l10n.products,
          // The listing screen already knows how to page, switch shape, add to
          // bag and favourite — it takes any collection provider, and this is
          // one. Rebuilding a second grid here would be a second thing to fix.
          // The name rides along so the page is titled with the shop rather
          // than the word "products".
          onSeeAll: () => context.push(
            Uri(
              path: RoutePaths.sellerProductsOf(sellerId),
              queryParameters: sellerName.isEmpty ? null : {'name': sellerName},
            ).toString(),
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 160,
                child: DsProductCard(
                  title: product.title,
                  price: product.price?.format() ?? '',
                  imageUrl: product.coverUrl,
                  blurHash: product.coverBlurHash,
                  compareAtPrice: product.hasDiscount
                      ? product.compareAtPrice?.format()
                      : null,
                  discountPercent: product.hasDiscount
                      ? product.discountPercent
                      : null,
                  rating: product.rating > 0 ? product.rating : null,
                  ratingCount: product.reviewsCount > 0
                      ? product.reviewsCount
                      : null,
                  soldOut: !product.inStock,
                  onTap: () =>
                      context.push(RoutePaths.productDetailsOf(product.id)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// What her customers said, and the way to add to it.
class _SellerReviews extends ConsumerWidget {
  const _SellerReviews({required this.sellerId, required this.isMe});

  final String sellerId;
  final bool isMe;

  static const _previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reputation = ref.watch(sellerReputationProvider(sellerId));
    final reviews = ref.watch(sellerReviewsProvider(sellerId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.l10n.reviewsAndRatings,
          // Reviewing the shop, not a piece in it — `submitSellerReview` has
          // existed the whole time with nothing calling it.
          action: isMe
              ? null
              : _WriteReviewButton(
                  onPressed: () => showReviewComposer(
                    context: context,
                    onSubmit:
                        ({
                          required rating,
                          required title,
                          required body,
                        }) => ref
                            .read(reputationActionsProvider)
                            .submitSellerReview(
                              sellerId: sellerId,
                              rating: rating,
                              title: title,
                              body: body,
                            ),
                    onSubmitted: () {
                      ref.invalidate(sellerReviewsProvider(sellerId));
                      ref.invalidate(sellerReputationProvider(sellerId));
                    },
                  ),
                ),
        ),
        const SizedBox(height: DsSpacing.sm),
        reputation.when(
          loading: () => const SizedBox.shrink(),
          // A summary that will not load is not worth an error state over the
          // reviews themselves, which are the point of the section.
          error: (_, _) => const SizedBox.shrink(),
          data: (summary) => _RatingSummary(
            average: summary.reputation.averageRating,
            count: summary.reputation.reviewsCount,
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        reviews.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: DsSpacing.lg),
            child: Center(child: DsLoadingIndicator()),
          ),
          error: (error, _) => DsErrorState(
            message: messageOf(error),
            onRetry: () => ref.invalidate(sellerReviewsProvider(sellerId)),
          ),
          data: (all) => all.isEmpty
              ? DsEmptyState(
                  icon: Icons.rate_review_outlined,
                  title: context.l10n.emptyFeed,
                )
              : Column(
                  children: [
                    for (final review in all.take(_previewCount)) ...[
                      ReviewCard(review: review),
                      const SizedBox(height: DsSpacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.average, required this.count});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final colors = context.dsColors;

    return Row(
      children: [
        Icon(Icons.star_rounded, color: colors.warning, size: 20),
        DsGaps.hXxs,
        Text(
          average.toStringAsFixed(1),
          style: context.dsText.cardTitle.bold.tint(colors.onSurface),
        ),
        DsGaps.hXs,
        Text(
          '($count)',
          style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll, this.action});

  final String title;
  final VoidCallback? onSeeAll;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.dsText.cardTitle.bold.tint(
              context.dsColors.onSurface,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: Text(context.l10n.viewAll)),
        ?action,
      ],
    );
  }
}

class _WriteReviewButton extends StatelessWidget {
  const _WriteReviewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.rate_review_outlined, size: 16),
    label: Text(context.l10n.reviewsWriteAction),
  );
}
