import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:reem/core/design_system/components/badges/ds_badge.dart';
import 'package:reem/core/design_system/components/buttons/ds_icon_button.dart';
import 'package:reem/core/design_system/components/loaders/ds_skeleton.dart';
import 'package:reem/core/design_system/foundation/motion/animations/scale_animations.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/shadow_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';

/// A premium product card for grids and carousels.
///
/// Generic by design — feature code passes already-formatted price strings and
/// callbacks; the card owns layout, motion and theming only.
class DsProductCard extends StatelessWidget {
  const DsProductCard({
    super.key,
    required this.title,
    required this.price,
    this.imageUrl,
    this.blurHash,
    this.compareAtPrice,
    this.discountPercent,
    this.sellerName,
    this.rating,
    this.ratingCount,
    this.isNew = false,
    this.soldOut = false,
    this.badgeLabel,
    this.cues = const [],
    this.onTap,
    this.action,
    this.onAddToCart,
    this.imageAspectRatio = 3 / 4,
  });

  final String title;
  final String price;
  final String? imageUrl;

  /// A blurred stand-in for the photograph, drawn while it is still arriving.
  /// Comes from `ProductMedia.blur_hash`; null for an external link, in which
  /// case the card falls back to a plain placeholder.
  final String? blurHash;
  final String? compareAtPrice;
  final int? discountPercent;
  final String? sellerName;
  final double? rating;
  final int? ratingCount;
  final bool isNew;
  final bool soldOut;
  final String? badgeLabel;

  /// Honest badges from the server: real scarcity, real social proof, a real
  /// anchor. Rendered verbatim and never composed here — the server has
  /// already decided what it is willing to claim, and an empty list means the
  /// truthful answer was to say nothing.
  ///
  /// At most two are drawn. A card wearing four badges is a card whose badges
  /// have stopped meaning anything, and the list arrives strongest-first.
  final List<DsProductCue> cues;

  final VoidCallback? onTap;

  /// The product's own interaction, floated over the top-end corner of the
  /// photograph.
  ///
  /// A widget rather than the `isFavorite` + `onFavoriteToggle` pair this card
  /// used to take. That pair asked every caller to decide what a heart on a
  /// product means and to wire it to a store of its choosing — and exactly one
  /// caller ever passed it, so search results and visual-search matches had no
  /// interaction at all. Feature code passes
  /// `DsProductActions.of(context, product, DsProductSurface.tile)`, which is
  /// the one answer the whole app shares.
  final Widget? action;
  final VoidCallback? onAddToCart;
  final double imageAspectRatio;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    final card = Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
        boxShadow: context.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Media(
            imageUrl: imageUrl,
            blurHash: blurHash,
            aspectRatio: imageAspectRatio,
            soldOut: soldOut,
            discountPercent: discountPercent,
            isNew: isNew,
            badgeLabel: badgeLabel,
            action: action,
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sellerName != null) ...[
                  Text(
                    sellerName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.overline(c.onSurfaceVariant),
                  ),
                  const SizedBox(height: DsSpacing.xxs),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: DsTypography.semiBold,
                        height: 1.25,
                      ),
                ),
                if (rating != null) ...[
                  const SizedBox(height: DsSpacing.xs),
                  _Rating(rating: rating!, count: ratingCount),
                ],
                if (cues.isNotEmpty) ...[
                  const SizedBox(height: DsSpacing.xs),
                  _Cues(cues: cues),
                ],
                const SizedBox(height: DsSpacing.xs),
                _PriceRow(
                  price: price,
                  compareAt: compareAtPrice,
                  onAddToCart: soldOut ? null : onAddToCart,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return DsScaleAnimations.tapScale(
      // The card's own text — name, price, badges — is what a screen reader
      // should read, so no label is supplied here; the tap semantics are what
      // was missing.
      enabled: onTap != null,
      pressedScale: 0.98,
      onTap: onTap!,
      child: card,
    );
  }
}

/// One thing the marketplace can honestly say, as the card needs it.
///
/// Deliberately a plain value rather than the domain entity: the design system
/// does not depend on `core/shared`, and a card that imported an entity to
/// read two strings would tie every screen's widget tree to the catalogue's
/// shape.
class DsProductCue {
  const DsProductCue({required this.label, required this.tone});

  final String label;
  final DsBadgeTone tone;
}

class _Cues extends StatelessWidget {
  const _Cues({required this.cues});

  final List<DsProductCue> cues;

  @override
  Widget build(BuildContext context) {
    // Two at most, strongest first. Wrapped rather than in a Row so a long
    // Arabic phrase moves to its own line instead of being clipped — a
    // half-shown claim is worse than an absent one.
    return Wrap(
      spacing: DsSpacing.xxs,
      runSpacing: DsSpacing.xxs,
      children: [
        for (final cue in cues.take(2))
          DsBadge(label: cue.label, tone: cue.tone),
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({
    required this.imageUrl,
    required this.blurHash,
    required this.aspectRatio,

    required this.soldOut,
    required this.discountPercent,
    required this.isNew,
    required this.badgeLabel,
    required this.action,
  });

  final String? imageUrl;
  final String? blurHash;
  final double aspectRatio;

  final bool soldOut;
  final int? discountPercent;
  final bool isNew;
  final String? badgeLabel;
  final Widget? action;

  /// The hash when there is one, a flat swatch when there is not. Decoded at
  /// 32×32 — all the detail a blur hash carries — so it costs nothing to draw.
  Widget _placeholder(DsColorScheme c) {
    final hash = blurHash;
    if (hash == null || hash.isEmpty) return ColoredBox(color: c.shimmerBase);
    return BlurHash(hash: hash, imageFit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) => CachedNetworkImage(
                imageUrl: MediaVariants.thumb(imageUrl!),
                fit: BoxFit.cover,
                memCacheWidth: MediaDecode.widthFrom(context, constraints),
                placeholder: (_, _) => _placeholder(c),
                errorWidget: (_, _, _) => _fallback(c),
              ),
            )
          else
            _fallback(c),
          if (soldOut)
            Container(
              color: c.surface.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm,
                  vertical: DsSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: c.inverseSurface.withValues(alpha: 0.85),
                  borderRadius: DsRadius.borderPill,
                ),
                child: Text(
                  context.l10n.soldOut,
                  style: context.dsText.labelMedium.semibold.tint(c.onInverseSurface),
                ),
              ),
            ),
          // Badges (top-start)
          Positioned(
            top: DsSpacing.xs,
            left: DsSpacing.xs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (discountPercent != null && discountPercent! > 0)
                  DsDiscountBadge(percentOff: discountPercent!),
                if (isNew) ...[
                  if (discountPercent != null && discountPercent! > 0)
                    const SizedBox(height: DsSpacing.xxs),
                  const DsBadge.solid(label: 'NEW', tone: DsBadgeTone.accent),
                ],
                if (badgeLabel != null) ...[
                  const SizedBox(height: DsSpacing.xxs),
                  DsBadge.solid(label: badgeLabel!, tone: DsBadgeTone.primary),
                ],
              ],
            ),
          ),
          // The product's interaction (top-end).
          if (action case final action?)
            PositionedDirectional(
              top: DsSpacing.xxs,
              end: DsSpacing.xxs,
              child: action,
            ),
        ],
      ),
    );
  }

  Widget _fallback(DsColorScheme c) => ColoredBox(
        color: c.surfaceVariant,
        child: Icon(Icons.image_outlined,
            color: c.onSurfaceVariant.withValues(alpha: 0.5), size: 36),
      );
}

class _Rating extends StatelessWidget {
  const _Rating({required this.rating, this.count});

  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 15, color: c.rating),
        const SizedBox(width: DsSpacing.xxs),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: c.onSurface,
                fontWeight: DsTypography.semiBold,
              ),
        ),
        if (count != null) ...[
          const SizedBox(width: DsSpacing.xxs),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.price,
    this.compareAt,
    this.onAddToCart,
  });

  final String price;
  final String? compareAt;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(price, style: DsTypography.price(c.price)),
              if (compareAt != null)
                Text(
                  compareAt!,
                  style: DsTypography.priceStrike(c.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (onAddToCart != null)
          DsIconButton(
            icon: Icons.add_shopping_cart_rounded,
            tooltip: 'أضيفي إلى السلة',
            variant: DsIconButtonVariant.primary,
            size: 38,
            iconSize: DsConstraints.iconSm,
            onPressed: onAddToCart,
          ),
      ],
    );
  }
}

/// Loading placeholder matching [DsProductCard]'s footprint.
class DsProductCardSkeleton extends StatelessWidget {
  const DsProductCardSkeleton({super.key, this.imageAspectRatio = 3 / 4});

  final double imageAspectRatio;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: imageAspectRatio,
              child: const DsSkeleton(height: double.infinity, borderRadius: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(DsSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  DsSkeleton.line(width: 70),
                  SizedBox(height: DsSpacing.xs),
                  DsSkeleton.line(width: double.infinity),
                  SizedBox(height: DsSpacing.xxs),
                  DsSkeleton.line(width: 120),
                  SizedBox(height: DsSpacing.sm),
                  DsSkeleton.line(width: 80, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
