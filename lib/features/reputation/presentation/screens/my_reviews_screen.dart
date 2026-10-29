import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';

/// Everything she has written about a piece or a boutique — kept like notes
/// tucked into the frame of her mirror.
///
/// Her profile already showed the count and the average; the row that offered
/// to open them led to a "coming soon" sheet, because nothing could list them.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reviews = ref.watch(myReviewsProvider);

    return OharaScrollPage(
      onRefresh: () async => ref.refresh(myReviewsProvider.future),
      slivers: [
        VanityAppBar(
          title: l10n.myReviews,
          subtitle: l10n.myReviewsSubtitle,
          icon: Icons.rate_review_outlined,
          showBack: true,
        ),
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
    final gutter = vanityGutter(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 140),
      sliver: SliverList.separated(
        itemCount: data.reviews.length + 1,
        separatorBuilder: (_, _) => DsGaps.vLg,
        itemBuilder: (context, index) {
          if (index == 0) return _Summary(data: data);
          return _ReviewCard(review: data.reviews[index - 1]);
        },
      ),
    );
  }
}

/// How many she has written and the stars she gives on average, as a strand
/// of five pearls lit up to her average.
class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final MyReviews data;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: DsSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxl,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [palette.primarySoft, palette.goldSoft],
        ),
        border: Border.all(color: palette.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.reviewsWritten(data.count),
                  style: context.dsText.sectionTitle.displayFamily.bold.tint(
                    palette.ink,
                  ),
                ),
                if (data.count > 0) ...[
                  DsGaps.vSm,
                  _PearlStrand(rating: data.average),
                ],
              ],
            ),
          ),
          if (data.count > 0) ...[
            DsGaps.hMd,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.average.toStringAsFixed(1),
                  style: context.dsText.hero.displayFamily.bold.tint(
                    palette.ink,
                  ),
                ),
                Text(
                  context.l10n.averageYouGive,
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Five pearls on a thread, lit gold up to [rating] (a half-lit pearl for a
/// half star).
class _PearlStrand extends StatelessWidget {
  const _PearlStrand({required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      label: rating.toStringAsFixed(1),
      excludeSemantics: true,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          // The thread.
          Positioned.fill(
            child: Center(child: Container(height: 1, color: palette.gold)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) SizedBox(width: size * 0.35),
                _Pearl(fill: (rating - i).clamp(0.0, 1.0), size: size),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Pearl extends StatelessWidget {
  const _Pearl({required this.fill, required this.size});

  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final lit = fill >= 0.75;
    final half = !lit && fill >= 0.25;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: lit
              ? const [DsColors.gold100, DsColors.gold400]
              : [
                  Color.lerp(palette.surface, DsColors.onMedia, 0.5)!,
                  Color.lerp(palette.surface, palette.primary, 0.15)!,
                ],
        ),
        border: Border.all(
          color: lit || half
              ? DsColors.gold500
              : palette.primary.withValues(alpha: 0.25),
        ),
      ),
      child: half
          ? ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.5,
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DsColors.gold300,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// One review, as a note tucked into the mirror's frame: pinned with a gold
/// pearl, the piece or boutique in a small arched window, her words, and —
/// when there is one — the seller's answer folded in under it.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final AuthoredReview review;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final l10n = context.l10n;
    final body = review.body?.trim() ?? '';
    final title = review.title?.trim() ?? '';
    final open = review.isAboutProduct
        ? () => context.push(RoutePaths.productDetailsOf(review.subject.id))
        : () => context.push(RoutePaths.userProfileOf(review.subject.id));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: palette.surface,
          borderRadius: DsRadius.borderXxl,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.md,
                DsSpacing.lg,
                DsSpacing.md,
                DsSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderXxl,
                border: Border.all(color: palette.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Thumb(review: review),
                      DsGaps.hMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              review.subject.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.dsText.bodyStrong.tint(
                                palette.ink,
                              ),
                            ),
                            if (!review.isAboutProduct) ...[
                              DsGaps.vXxxs,
                              Text(
                                l10n.reviewAboutShop,
                                style: context.dsText.caption.tint(
                                  palette.muted,
                                ),
                              ),
                            ],
                            DsGaps.vXs,
                            Row(
                              children: [
                                _PearlStrand(
                                  rating: review.rating.toDouble(),
                                  size: 12,
                                ),
                                DsGaps.hSm,
                                Expanded(
                                  child: Text(
                                    formatRelativeTime(l10n, review.createdAt),
                                    style: context.dsText.caption.tint(
                                      palette.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (title.isNotEmpty || body.isNotEmpty) ...[
                    DsGaps.vMd,
                    // Her words, opened with a large gold quotation mark.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // l10n-ignore: a quotation mark, not a word.
                          '“',
                          style: context.dsText.hero.displayFamily.tint(
                            palette.gold,
                          ),
                        ),
                        DsGaps.hXs,
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: DsSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title.isNotEmpty)
                                  Text(
                                    title,
                                    style: context.dsText.bodyStrong.tint(
                                      palette.ink,
                                    ),
                                  ),
                                if (body.isNotEmpty) ...[
                                  if (title.isNotEmpty) DsGaps.vXxs,
                                  Text(
                                    body,
                                    style: context.dsText.body
                                        .tint(palette.ink)
                                        .copyWith(height: 1.55),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // A review still in moderation is hers to see. Hiding it
                  // would look like the app had lost it, and she would write
                  // it again.
                  if (review.isPending || review.isRejected) ...[
                    DsGaps.vSm,
                    _StatusChip(
                      label: review.isPending
                          ? l10n.reviewPending
                          : l10n.reviewRejected,
                      tone: review.isPending
                          ? palette.caution
                          : palette.critical,
                    ),
                  ],
                  if (review.hasReply) ...[
                    DsGaps.vMd,
                    Container(
                      padding: DsSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: palette.primarySoft.withValues(alpha: 0.6),
                        borderRadius: DsRadius.borderLg,
                        border: BorderDirectional(
                          start: BorderSide(color: palette.gold, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.reply_rounded,
                                size: DsSizes.iconXs,
                                color: palette.primary,
                              ),
                              DsGaps.hXxs,
                              Text(
                                l10n.sellerReplied,
                                style: context.dsText.caption.semibold.tint(
                                  palette.primary,
                                ),
                              ),
                            ],
                          ),
                          DsGaps.vXxs,
                          Text(
                            review.sellerReply!.trim(),
                            style: context.dsText.bodySmall
                                .tint(palette.ink)
                                .copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // The pin.
        PositionedDirectional(
          top: -6,
          end: DsSpacing.xl,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.35, -0.4),
                colors: [DsColors.gold100, DsColors.gold400],
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.gold.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.review});

  final AuthoredReview review;

  @override
  Widget build(BuildContext context) {
    // A boutique is a person, so it gets the round avatar treatment; a piece
    // sits in a small arched window.
    if (!review.isAboutProduct) {
      return DsAvatar(
        imageUrl: review.subject.imageUrl,
        name: review.subject.title,
        size: 56,
      );
    }

    final palette = context.boutique;
    final url = review.subject.imageUrl;
    return ClipPath(
      clipper: const DsArchClipper(),
      child: SizedBox(
        width: 52,
        height: 62,
        child: url == null || url.isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [palette.primarySoft, palette.goldSoft],
                  ),
                ),
                child: Icon(
                  Icons.redeem_rounded,
                  color: palette.primary,
                  size: DsSizes.iconMd,
                ),
              )
            : AuthorizedMediaImage(url: url, fit: BoxFit.cover),
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
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: context.dsText.caption.semibold.tint(tone)),
    );
  }
}
