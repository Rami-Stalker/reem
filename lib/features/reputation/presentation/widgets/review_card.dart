import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/reputation/domain/entities/reputation_entities.dart';

/// One review, wherever a review is shown.
///
/// It lived privately inside the product page. The seller profile needed the
/// same card — same author row, same stars, same pending and verified badges —
/// and a second copy is how two lists of the same thing start disagreeing
/// about what a pending review looks like.

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final ReviewEntity review;

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
              CircleAvatar(
                backgroundImage: review.user.imageUrl == null
                    ? null
                    : NetworkImage(review.user.imageUrl!),
                child: review.user.imageUrl == null
                    ? Text(review.user.name.isEmpty ? '?' : review.user.name[0])
                    : null,
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.semibold,
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < review.rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: colors.warning,
                          size: 16,
                        ),
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
            Text(
              review.title!,
              style: context.dsText.body.bold,
            ),
          ],
          if (review.body?.isNotEmpty == true) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              review.body!,
              style: context.dsText.body.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
            ),
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
