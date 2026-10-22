import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:reem/features/product_social/presentation/widgets/product_like_button.dart';
import 'package:reem/features/visual_search/domain/entities/visual_match.dart';
import 'package:reem/features/visual_search/presentation/widgets/visual_similarity_badge.dart';

/// Two lines of `bodySmall`, reserved whether or not there is a reason.
const double _reasonHeight = 34;

/// The height a card needs on top of its image, for a caller sizing a grid.
///
/// Exported so the grid and the card cannot disagree: `visual_search_screen`
/// sizes its cells from this rather than from a number tuned by eye that stops
/// being right the moment the card gains a line.
///
/// The 176 is what [DsProductCard] stacks under its image at the default text
/// scale — seller line, two-line title, rating row, price row, and the card's
/// own padding — measured rather than estimated, after an estimate came up
/// short and clipped every card.
///
/// The price row is what makes it this tall. At a two-column phone width a
/// long Arabic amount ("١٬١٣٨٬٠٠٠ ل.س") wraps onto a second line and, with a
/// struck-through compare-at price beneath it, the row is half as tall again
/// as it looks in a mockup where the numbers are short.
///
/// The trailing pixel is slack for sub-pixel rounding: the grid divides the
/// available width into columns and the remainder lands in the tile height, so
/// an exact fit overflows by a third of a pixel on some widths.
const double visualMatchCardChrome = 176 + _reasonHeight + DsSpacing.xxs + 1;

/// The image aspect [DsProductCard] draws at, repeated here for the same
/// reason.
const double visualMatchImageAspect = 3 / 4;

/// One result: photograph, name, price, rating, seller, similarity, cart.
///
/// Built around [DsProductCard] rather than beside it. Everything a card in
/// this app shows about a product — the blur-hash placeholder, the discount
/// rule, the sold-out treatment, the tap target — already lives there, and a
/// second implementation would drift within a release. What visual search adds
/// sits *around* it: the percentage over the corner of the image, and the
/// server's sentence underneath.
///
/// The image shown is [VisualMatch.matchedMediaUrl] when the server named one.
/// That is the photograph the percentage is actually about — often a listing's
/// third, not its first — and showing the primary instead would put a number
/// next to a picture it was not computed from.
class VisualMatchCard extends StatelessWidget {
  const VisualMatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.onAddToCart,
    this.onFeedback,
  });

  final VisualMatch match;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final void Function(StylistFeedback feedback)? onFeedback;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final product = match.product;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            DsProductCard(
              title: product.title,
              price: product.price?.format() ?? '',
              imageUrl: match.matchedMediaUrl ?? product.coverUrl,
              blurHash: product.coverBlurHash,
              compareAtPrice: product.hasDiscount
                  ? product.compareAtPrice?.format()
                  : null,
              discountPercent: product.hasDiscount
                  ? product.discountPercent
                  : null,
              sellerName: product.displaySeller?.name ?? '',
              rating: product.rating > 0 ? product.rating : null,
              ratingCount: product.reviewsCount > 0
                  ? product.reviewsCount
                  : null,
              soldOut: !product.inStock,
              onTap: onTap,
              onAddToCart: product.inStock ? onAddToCart : null,
              // The product's own like, like every other card on the platform
              // — and here it is *also* the signal that teaches the visual
              // ranker, which is what her liking a match means. One heart, one
              // meaning; a second one beside it for "feedback" was a
              // distinction only this screen understood.
              action: ProductLikeButton(
                key: ValueKey('like-${product.id}'),
                product: product,
                onChanged: onFeedback == null
                    ? null
                    : (liked) => onFeedback!(
                        liked ? StylistFeedback.liked : StylistFeedback.none,
                      ),
              ),
            ),
            // Directional rather than `Positioned`: the app is RTL, and a
            // badge pinned to the physical left would sit under the discount
            // flag on every card that has one.
            PositionedDirectional(
              top: DsSpacing.xs,
              start: DsSpacing.xs,
              child: VisualSimilarityBadge(
                percent: match.similarityPercent,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xxs),
        // A fixed slot rather than an intrinsic one.
        //
        // These cards live in a `SliverGrid`, which gives every cell the same
        // height; a reason that wraps to two lines on one card and one on the
        // next made the tallest card overflow its cell by up to a hundred
        // pixels. Reserving the space unconditionally — even when there is no
        // reason to show — keeps every card exactly as tall as every other,
        // which is what a grid needs and what a rail of cards should look like
        // anyway.
        SizedBox(
          height: _reasonHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
            child: Text(
              match.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}
