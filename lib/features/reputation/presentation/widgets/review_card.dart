import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_lightbox.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/reputation/domain/entities/fit_entities.dart';
import 'package:reem/features/reputation/domain/entities/reputation_entities.dart';
import 'package:reem/features/reputation/presentation/widgets/fit_labels.dart';

/// One review, wherever a review is shown.
///
/// It lived privately inside the product page. The seller profile needed the
/// same card — same author row, same stars, same pending and verified badges —
/// and a second copy is how two lists of the same thing start disagreeing
/// about what a pending review looks like.

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final ReviewEntity review;

  void _openAuthor(BuildContext context) {
    if (review.user.id.isEmpty) return;
    context.push(RoutePaths.userProfileOf(review.user.id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        boxShadow: context.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The reviewer's face opens her page, as it does on a comment.
              DsAvatar(
                imageUrl: review.user.imageUrl,
                name: review.user.name,
                size: 40,
                onTap: () => _openAuthor(context),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openAuthor(context),
                      child: Text(
                        review.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.semibold,
                      ),
                    ),
                    // The stars she chose when she wrote it — the review's own
                    // `rating`, 1 to 5, validated by the server.
                    if (review.rating >= 1 && review.rating <= 5)
                      Semantics(
                        label: context.l10n.reviewsRatedOutOfFive(
                          review.rating,
                        ),
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            for (var index = 0; index < 5; index++)
                              Icon(
                                index < review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: colors.warning,
                                size: 16,
                              ),
                            DsGaps.hXxs,
                            Text(
                              '${review.rating}/5',
                              style: context.dsText.caption.tabular,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Her own review, still with the moderators. It is in this list
              // only for her — everyone else sees approved reviews — and it
              // says so, because a review that appeared unlabelled would read
              // as published.
              if (review.status == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.sm,
                    vertical: DsSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warningContainer,
                    borderRadius: DsRadius.borderPill,
                  ),
                  child: Text(
                    context.l10n.reviewPending,
                    style: context.dsText.body.semibold.tint(colors.warning),
                  ),
                )
              else if (review.verifiedPurchase)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.sm,
                    vertical: DsSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.successContainer,
                    borderRadius: DsRadius.borderPill,
                  ),
                  child: Text(
                    context.l10n.reviewsVerified,
                    style: context.dsText.body.semibold.tint(colors.success),
                  ),
                ),
            ],
          ),
          if (review.title?.isNotEmpty == true) ...[
            const SizedBox(height: DsSpacing.md),
            Text(review.title!, style: context.dsText.body.bold),
          ],
          if (review.body?.isNotEmpty == true) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              review.body!,
              style: context.dsText.body
                  .tint(colors.onSurfaceVariant)
                  .copyWith(height: 1.5),
            ),
          ],
          if (review.hasFitFacts) ...[DsGaps.vSm, _FitFacts(review: review)],
          if (review.photos.isNotEmpty) ...[
            DsGaps.vSm,
            _PhotoStrip(photos: review.photos),
          ],
          if (review.status == 'pending') ...[
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: DsSizes.iconXs,
                  color: colors.onSurfaceVariant,
                ),
                DsGaps.hXxs,
                Expanded(
                  child: Text(
                    context.l10n.reviewsPendingYours,
                    style: context.dsText.caption.tint(colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// «مقاسه مضبوط · اشترت M».
///
/// How it fit and the size that shipped — facts about the *piece*. Nothing
/// about the reviewer's body is drawn here, because the server never sends
/// it.
class _FitFacts extends StatelessWidget {
  const _FitFacts({required this.review});

  final ReviewEntity review;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fit = review.fit;
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        if (fit != null)
          DsBadge(
            label: FitLabels.fit(l10n, fit),
            icon: FitLabels.icon(fit),
            tone: fit == ReviewFit.trueToSize
                ? DsBadgeTone.success
                : DsBadgeTone.warning,
          ),
        if (review.sizeBought != null)
          DsBadge(
            label: l10n.fitBoughtSize(review.sizeBought!),
            tone: DsBadgeTone.neutral,
          ),
      ],
    );
  }
}

/// The photographs of the piece, as a row of thumbnails that open full screen.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SizedBox(
      height: DsSizes.thumbLg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => DsGaps.hXs,
        itemBuilder: (context, index) => Semantics(
          button: true,
          label: context.l10n.fitPhotoOpen(index + 1),
          child: GestureDetector(
            onTap: () => MediaLightbox.open(context, url: photos[index]),
            child: ClipRRect(
              borderRadius: DsRadius.borderMd,
              child: SizedBox(
                width: DsSizes.thumbLg,
                height: DsSizes.thumbLg,
                child: AuthorizedMediaImage(
                  url: photos[index],
                  fallback: Container(color: colors.surfaceVariant),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
