import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/seller_reviews/domain/entities/seller_review.dart';

/// One review, with her answer under it if she has written one.
///
/// The reply is drawn *inside* the same card, indented and tinted, because
/// that is exactly how a customer will see it on the product page. A seller
/// composing an answer should be looking at the shape the buyer gets.
class SellerReviewCard extends StatelessWidget {
  const SellerReviewCard({
    super.key,
    required this.review,
    required this.isBusy,
    required this.onReply,
  });

  final SellerReviewItem review;
  final bool isBusy;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    // A review still waiting on her answer is tacked down with a champagne
    // stitch, so the unanswered ones stand out of the list without a badge.
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(author: review.author),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.semibold.tint(palette.ink),
                    ),
                    Text(
                      formatCalendarDate(context.l10n, review.createdAt),
                      style: context.dsText.caption.tint(palette.muted),
                    ),
                  ],
                ),
              ),
              _Stars(rating: review.rating),
            ],
          ),

          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              if (review.target == ReviewTarget.seller)
                SellerStatusPill(
                  label: l10n.reviewsAboutShop,
                  icon: Icons.storefront_rounded,
                  color: palette.primary,
                )
              else if (review.productTitle != null)
                SellerStatusPill(
                  label: review.productTitle!,
                  icon: Icons.inventory_2_outlined,
                  color: palette.muted,
                ),
              if (review.verifiedPurchase)
                SellerStatusPill(
                  label: l10n.reviewsVerifiedBuyer,
                  icon: Icons.verified_rounded,
                  color: palette.positive,
                ),
            ],
          ),

          if (review.title case final String title when title.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              title,
              style: context.dsText.body.semibold.tint(palette.ink),
            ),
          ],
          if (review.body case final String body when body.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              body,
              style: context.dsText.body.tint(palette.ink).copyWith(height: 1.6),
            ),
          ],

          if (review.isAnswered) ...[
            const SizedBox(height: DsSpacing.md),
            _Reply(review: review),
          ],

          const SizedBox(height: DsSpacing.md),
          if (isBusy)
            const Center(
              child: DsLoadingIndicator.inline(),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: review.isAnswered
                  ? TextButton.icon(
                      onPressed: onReply,
                      icon: const Icon(Icons.edit_outlined, size: DsSizes.iconXs),
                      label: Text(l10n.reviewsEditReply),
                    )
                  // The one thing to do with an unanswered review, so it is a
                  // real button rather than a link.
                  : IntrinsicWidth(
                      child: DsButton(
                        label: l10n.reviewsReplyAction,
                        icon: Icons.reply_rounded,
                        size: DsButtonSize.sm,
                        isExpanded: false,
                        onPressed: onReply,
                      ),
                    ),
            ),
        ],
      );

    return review.isAnswered
        ? SellerPanel(child: content)
        : StitchedCard(
            accent: palette.gold,
            padding: DsSpacing.paddingLg,
            child: content,
          );
  }
}

/// Her published answer, drawn the way the buyer will see it.
class _Reply extends StatelessWidget {
  const _Reply({required this.review});

  final SellerReviewItem review;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.primarySoft,
        borderRadius: DsRadius.borderMd,
        // A leading rule, so the answer reads as attached to the review above
        // rather than as a second review.
        border: BorderDirectional(
          start: BorderSide(color: palette.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reviewsYourReply,
            style: context.dsText.caption.bold.tint(palette.primary),
          ),
          DsGaps.vXxxs,
          Text(
            review.reply!,
            style: context.dsText.body.tint(palette.ink).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: DsSizes.iconSm,
            color: i <= rating ? palette.gold : palette.line,
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.author});

  final ReviewAuthor author;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final initial = author.name.trim().isEmpty
        ? '؟'
        : author.name.trim().characters.first;

    return ClipOval(
      child: SizedBox(
        width: 38,
        height: 38,
        child: author.imageUrl == null
            ? ColoredBox(
                color: palette.primarySoft,
                child: Center(
                  child: Text(
                    initial,
                    style: context.dsText.body.bold.tint(palette.primary),
                  ),
                ),
              )
            : AuthorizedMediaImage(
                url: author.imageUrl!,
                variantWidth: MediaVariants.thumbnail,
              ),
      ),
    );
  }
}
