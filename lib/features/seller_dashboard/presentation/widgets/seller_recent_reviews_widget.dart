import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_misc.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';

class SellerRecentReviewsWidget extends ConsumerWidget {
  const SellerRecentReviewsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);

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
          // The reviews were readable here and answerable nowhere. The
          // heading now leads to the desk where she can write back.
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.sellerRecentReviews,
                  style: context.dsText.cardTitle
                      .copyWith(fontWeight: DsTypography.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(RoutePaths.sellerReviews),
                child: Text(context.l10n.sellerManageAll),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          ...reviews.asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: e.key < reviews.length - DsSpacing.xxxs ? DsSpacing.sm : DsSpacing.xxxs),
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
                  imageUrl: MediaVariants.thumb(review.customerAvatarUrl),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  memCacheWidth: MediaDecode.widthFor(context, 36),
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
                      style: context.dsText.tileTitle
                          .copyWith(fontWeight: DsTypography.semiBold),
                    ),
                    Text(
                      review.productTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.caption
                          .copyWith(color: c.onSurfaceVariant, fontSize: DsTypography.labelMicro),
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
                    style: context.dsText.caption.copyWith(
                      color: c.onSurfaceVariant,
                      fontSize: DsTypography.labelMicro,
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
            style: context.dsText.cardSubtitle
                .copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
