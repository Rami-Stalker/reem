import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:reem/features/reputation/presentation/widgets/review_card.dart';
import 'package:reem/features/reputation/presentation/widgets/review_composer.dart';

/// What her customers said, and the way to add to it — the reviews tab on a
/// boutique's page.
///
/// The page opened on a name, a follow button and a stats card, and stopped.
/// `sellerReviews` and `sellerReputation` were written, wired to real
/// endpoints, and read by nothing; this is where they are read.
class SellerReviewsSection extends ConsumerWidget {
  const SellerReviewsSection({
    super.key,
    required this.sellerId,
    required this.isMe,
  });

  final String sellerId;

  /// Her own shop: she cannot review herself.
  final bool isMe;

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
                    onSubmit: (draft) => ref
                            .read(reputationActionsProvider)
                            .submitSellerReview(
                              sellerId: sellerId,
                          rating: draft.rating,
                          title: draft.title,
                          body: draft.body,
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
                    for (final review in all) ...[
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
  const _SectionHeader({required this.title, this.action});

  final String title;
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
