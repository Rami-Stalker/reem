import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/reputation/domain/entities/reputation_entities.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';

/// Everything she has written about a piece or a boutique.
///
/// Her profile already showed the count and the average; the row that offered
/// to open them led to a "coming soon" sheet, because nothing could list them.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reviews = ref.watch(myReviewsProvider);

    return ReemScrollPage(
      onRefresh: () async => ref.refresh(myReviewsProvider.future),
      slivers: [
        PremiumAppBar(title: l10n.myReviews, showBack: true),
        reviews.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: DsErrorState(
              title: l10n.myReviewsFailed,
              message: messageOf(error),
              retryLabel: l10n.retry,
              onRetry: () => ref.invalidate(myReviewsProvider),
            ),
          ),
          data: (data) => data.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: DsEmptyState(
                    icon: Icons.rate_review_outlined,
                    title: l10n.myReviewsEmpty,
                    message: l10n.myReviewsEmptyBody,
                    actionLabel: l10n.myReviewsEmptyAction,
                    onAction: () => context.push(RoutePaths.orders),
                  ),
                )
              : _Reviews(data: data),
        ),
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.data});

  final MyReviews data;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        140,
      ),
      sliver: SliverList.separated(
        itemCount: data.reviews.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) return _Summary(data: data);
          return _ReviewCard(review: data.reviews[index - 1]);
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final MyReviews data;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.reviewsWritten(data.count),
                  style: context.dsText.cardTitle
                      .copyWith(fontWeight: DsTypography.bold),
                ),
                DsGaps.vXxxs,
                Text(
                  context.l10n.myReviewsSubtitle,
                  style: context.dsText.cardSubtitle
                      .copyWith(color: c.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
          if (data.count > 0) ...[
            const SizedBox(width: DsSpacing.md),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: c.warning),
                    DsGaps.hXxs,
                    Text(
                      data.average.toStringAsFixed(1),
                      style: context.dsText.cardTitle
                          .copyWith(fontWeight: DsTypography.bold),
                    ),
                  ],
                ),
                Text(
                  context.l10n.averageYouGive,
                  style: context.dsText.caption
                      .copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final AuthoredReview review;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final body = review.body?.trim() ?? '';

    return SurfaceCard(
      onTap: review.isAboutProduct
          ? () => context.push(
              RoutePaths.productDetailsOf(review.subject.id),
            )
          : () => context.push(RoutePaths.userProfileOf(review.subject.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(review: review),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      review.subject.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.tileTitle
                          .copyWith(fontWeight: DsTypography.semiBold),
                    ),
                    if (!review.isAboutProduct) ...[
                      DsGaps.vXxxs,
                      Text(
                        l10n.reviewAboutShop,
                        style: context.dsText.caption
                            .copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: DsSpacing.xs),
                    Row(
                      children: [
                        _Stars(rating: review.rating),
                        const SizedBox(width: DsSpacing.sm),
                        Expanded(
                          child: Text(
                            formatRelativeTime(l10n, review.createdAt),
                            style: context.dsText.caption
                                .copyWith(color: c.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.title != null && review.title!.trim().isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              review.title!.trim(),
              style: context.dsText.body
                  .copyWith(fontWeight: DsTypography.semiBold),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              body,
              style: context.dsText.body
                  .copyWith(color: c.onSurfaceVariant, height: 1.5),
            ),
          ],
          // A review still in moderation is hers to see. Hiding it would look
          // like the app had lost it, and she would write it again.
          if (review.isPending || review.isRejected) ...[
            const SizedBox(height: DsSpacing.sm),
            _StatusChip(
              label: review.isPending ? l10n.reviewPending : l10n.reviewRejected,
              tone: review.isPending ? c.warning : c.error,
            ),
          ],
          if (review.hasReply) ...[
            const SizedBox(height: DsSpacing.md),
            Container(
              padding: const EdgeInsets.all(DsSpacing.md),
              decoration: BoxDecoration(
                color: c.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: DsRadius.borderMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sellerReplied,
                    style: context.dsText.caption.copyWith(
                      color: c.primary,
                      fontWeight: DsTypography.semiBold,
                    ),
                  ),
                  DsGaps.vXxs,
                  Text(
                    review.sellerReply!.trim(),
                    style: context.dsText.cardSubtitle.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.review});

  final AuthoredReview review;

  @override
  Widget build(BuildContext context) {
    // A boutique is a person, so it gets the round avatar treatment; a piece
    // gets a square crop, the way it looks everywhere else in the app.
    if (!review.isAboutProduct) {
      return DsAvatar(
        imageUrl: review.subject.imageUrl,
        name: review.subject.title,
        size: 56,
      );
    }

    final c = context.dsColors;
    final url = review.subject.imageUrl;
    return ClipRRect(
      borderRadius: DsRadius.borderMd,
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null || url.isEmpty
            ? ColoredBox(color: c.secondaryContainer)
            : AuthorizedMediaImage(url: url, fit: BoxFit.cover),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 15,
          color: index < rating ? c.warning : c.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xxs),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: DsRadius.borderSm,
      ),
      child: Text(
        label,
        style: context.dsText.caption.copyWith(
              color: tone,
              fontWeight: DsTypography.semiBold,
            ),
      ),
    );
  }
}
