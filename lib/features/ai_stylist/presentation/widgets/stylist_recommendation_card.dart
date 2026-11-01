import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';

/// One recommendation, with the reason it was chosen.
///
/// The reason is not decoration and is not optional. A shop assistant who
/// hands you a dress says why; one who silently holds out six dresses is a
/// shelf. It is rendered server-side from the score components that actually
/// fired, so the sentence can always be defended.
class StylistRecommendationCard extends StatelessWidget {
  const StylistRecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.onLike,
    this.onDismiss,
    this.width = 220,
  });

  final StylistRecommendation recommendation;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onDismiss;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final product = recommendation.product;
    final seller = product.displaySeller;

    return AnimatedOpacity(
      duration: DsDurations.fast,
      // A dismissed card fades rather than disappearing: she can see that her
      // "لا يعجبني" registered, and undo it.
      opacity: recommendation.isDismissed ? 0.45 : 1,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DsRadius.card),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.10),
              blurRadius: DsSpacing.lg,
              spreadRadius: -DsSpacing.xxs,
              offset: const Offset(0, DsSpacing.xxs),
            ),
          ],
        ),
        child: Material(
          color: colors.card,
          borderRadius: BorderRadius.circular(DsRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Cover(recommendation: recommendation),
                // Expanded, not sized: the rail fixes the card's height while
                // the reason sentence is whatever the ranker wrote, and a
                // Column of intrinsic heights inside a fixed box is an
                // overflow waiting for a long enough explanation.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpacing.sm,
                      DsSpacing.sm,
                      DsSpacing.sm,
                      DsSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.body.semibold
                              .tint(colors.onSurface)
                              .copyWith(height: 1.35),
                        ),
                        if (seller != null) ...[
                          DsGaps.vXxxs,
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 12,
                                color: colors.onSurfaceVariant,
                              ),
                              DsGaps.hXxs,
                              Expanded(
                                child: Text(
                                  seller.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.dsText.caption.tint(colors.onSurfaceVariant),
                                ),
                              ),
                              if (product.rating > 0) ...[
                                Icon(Icons.star_rounded, size: 13, color: colors.warning),
                                DsGaps.hXxxs,
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: context.dsText.caption.semibold.tint(colors.onSurface),
                                ),
                              ],
                            ],
                          ),
                        ],
                        DsGaps.vXs,
                        // The flexible element, so a long reason is trimmed
                        // rather than pushing the feedback row off the card.
                        Expanded(child: _Reason(text: recommendation.reason)),
                        if (onLike != null || onDismiss != null) ...[
                          DsGaps.vXs,
                          _FeedbackRow(
                            recommendation: recommendation,
                            onLike: onLike,
                            onDismiss: onDismiss,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.recommendation});

  final StylistRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final product = recommendation.product;
    final price = recommendation.displayPrice;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (product.coverUrl != null)
            AuthorizedMediaImage(
              url: product.coverUrl!,
              blurHash: product.coverBlurHash,
              variantWidth: MediaVariants.thumbnail,
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: context.boutique.signatureGradient),
              child: const Icon(Icons.checkroom_rounded, color: DsColors.onMedia, size: 36),
            ),
          // A soft wash at the foot of the photo, so the price reads on any
          // picture without a hard band across it.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 72,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: DsGradients.imageScrim),
            ),
          ),
          if (recommendation.slotLabel != null)
            PositionedDirectional(
              top: DsSpacing.xs,
              start: DsSpacing.xs,
              child: _Pill(
                label: recommendation.slotLabel!,
                background: colors.surface.withValues(alpha: 0.92),
                foreground: colors.primary,
                icon: Icons.auto_awesome_rounded,
              ),
            ),
          if (price != null)
            PositionedDirectional(
              bottom: DsSpacing.xs,
              start: DsSpacing.sm,
              child: Text(
                price.format(),
                style: context.dsText.labelLarge.bold.tint(DsColors.onMedia),
              ),
            ),
          // Availability is stated, never implied. The stylist only ever offers
          // live offers, so this is the rare case where one sold out between
          // the answer and the render.
          if (!recommendation.inStock)
            PositionedDirectional(
              bottom: DsSpacing.xs,
              end: DsSpacing.xs,
              child: _Pill(
                label: context.l10n.stylistSoldOut,
                background: colors.error,
                foreground: colors.onError,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DsRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            DsGaps.hXxxs,
          ],
          Text(label, style: context.dsText.caption.semibold.tint(foreground)),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DsRadius.md),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A thin rule in the brand gradient marks this as Ohara speaking.
            Container(
              width: 3,
              decoration: BoxDecoration(gradient: context.boutique.signatureGradient),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.xs),
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                  style: context.dsText.caption
                      .tint(colors.onSurfaceVariant)
                      .copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({
    required this.recommendation,
    this.onLike,
    this.onDismiss,
  });

  final StylistRecommendation recommendation;
  final VoidCallback? onLike;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Row(
      children: [
        if (onLike != null)
          _FeedbackButton(
            icon: recommendation.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: context.l10n.stylistLike,
            active: recommendation.isLiked,
            activeColor: colors.primary,
            onTap: onLike!,
          ),
        if (onLike != null && onDismiss != null)
          const SizedBox(width: DsSpacing.xs),
        if (onDismiss != null)
          _FeedbackButton(
            icon: recommendation.isDismissed
                ? Icons.thumb_down_rounded
                : Icons.thumb_down_off_alt_rounded,
            label: context.l10n.stylistNotForMe,
            active: recommendation.isDismissed,
            activeColor: colors.onSurfaceVariant,
            onTap: onDismiss!,
          ),
      ],
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final foreground = active ? activeColor : colors.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DsRadius.pill),
        child: AnimatedContainer(
          duration: DsDurations.fast,
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: active ? activeColor.withValues(alpha: 0.4) : colors.border,
            ),
            borderRadius: BorderRadius.circular(DsRadius.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: DsDurations.normal,
                curve: Curves.elasticOut,
                scale: active ? 1.2 : 1,
                child: Icon(icon, size: 14, color: foreground),
              ),
              const SizedBox(width: DsSpacing.xxs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.tint(foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
