import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../domain/entities/seller_misc.dart';
import '../providers/seller_dashboard_provider.dart';

class SellerRecentReviewsWidget extends ConsumerWidget {
  const SellerRecentReviewsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final theme = Theme.of(context);

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 200, borderRadius: DsRadius.xxl)),
      );
    }

    final reviews = state.data?.recentReviews ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent reviews',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: DsTypography.bold),
          ),
          const SizedBox(height: DsSpacing.sm),
          ...reviews.asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: e.key < reviews.length - 1 ? DsSpacing.sm : 0),
              child: _ReviewCard(review: e.value)
                  .animate(delay: (e.key * 70).ms)
                  .fadeIn(duration: 300.ms),
            );
          }),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final SellerRecentReview review;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: review.customerAvatarUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                  errorWidget: (_, _, _) => Container(
                    color: c.primaryContainer,
                    child: Icon(Icons.person_rounded,
                        color: c.primary, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: DsTypography.semiBold),
                    ),
                    Text(
                      review.productTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: c.onSurfaceVariant, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      return Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: i < review.rating
                            ? c.rating
                            : c.onSurfaceVariant.withValues(alpha: 0.3),
                      );
                    }),
                  ),
                  Text(
                    review.timeAgo,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: c.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            review.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
