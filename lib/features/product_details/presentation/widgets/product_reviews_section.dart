import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:ohara/features/reputation/presentation/widgets/product_fit_panel.dart';
import 'package:ohara/features/reputation/presentation/widgets/review_card.dart';
import 'package:ohara/features/reputation/presentation/widgets/review_composer.dart';

/// A product's reviews, with «تقييمات من بمقاسي» on top: how it fits, and the
/// two narrowings that matter before buying clothes — women her size, and
/// women who showed it on.
class ProductReviewsSection extends ConsumerStatefulWidget {
  const ProductReviewsSection({
    super.key,
    required this.productId,
    this.rating = 0,
    this.reviewsCount = 0,
  });

  final String? productId;

  /// The piece's average and how many reviews it is over — the product's
  /// own live figures, drawn under the heading.
  final double rating;
  final int reviewsCount;

  @override
  ConsumerState<ProductReviewsSection> createState() =>
      _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends ConsumerState<ProductReviewsSection> {
  var _filter = ReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final id = widget.productId;
    if (id == null || id.isEmpty) {
      return const SizedBox.shrink();
    }

    final key = (productId: id, filter: _filter);
    final reviews = ref.watch(productReviewsProvider(key));
    final fit = ref.watch(productFitProvider(id)).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewsHeader(
          rating: widget.rating,
          reviewsCount: widget.reviewsCount,
        ),
        DsGaps.vSm,
        _ReviewAction(
          productId: id,
          onWrite: () => _showReviewSheet(context, id),
        ),
        DsGaps.vMd,
        ProductFitPanel(productId: id),
        DsGaps.vMd,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            DsChip(
              label: context.l10n.reviewsFilterAll,
              selected: _filter == ReviewFilter.all,
              onTap: () => setState(() => _filter = ReviewFilter.all),
            ),
            DsChip(
              label: context.l10n.reviewsFilterNearMe,
              icon: Icons.person_search_rounded,
              selected: _filter == ReviewFilter.nearMe,
              onTap: () => setState(() => _filter = ReviewFilter.nearMe),
            ),
            DsChip(
              label: context.l10n.reviewsFilterPhotos,
              icon: Icons.photo_library_outlined,
              count: fit?.photosCount,
              selected: _filter == ReviewFilter.photos,
              onTap: () => setState(() => _filter = ReviewFilter.photos),
        ),
          ],
        ),
        DsGaps.vMd,
        reviews.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => _ReviewsMessage(
            icon: Icons.error_outline_rounded,
            title: context.l10n.reviewsUnavailable,
            message: messageOf(error),
            action: IconButton(
              tooltip: context.l10n.retry,
              onPressed: () => ref.invalidate(productReviewsProvider(key)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          data: (items) {
            if (items.isEmpty) return _empty(context, fit);
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => DsGaps.vMd,
              itemBuilder: (context, index) => ReviewCard(review: items[index]),
            );
          },
        ),
      ],
    );
  }

  /// Each filter's empty list means something different, and says so.
  Widget _empty(BuildContext context, ProductFit? fit) {
    final l10n = context.l10n;
    return switch (_filter) {
      // «من بمقاسي» before she has said her size is a question she has not
      // asked yet — answered with the profile, not with "nobody".
      ReviewFilter.nearMe when fit != null && !fit.hasProfile =>
        _ReviewsMessage(
          icon: Icons.straighten_rounded,
          title: l10n.reviewsNearMeNeedsProfileTitle,
          message: l10n.reviewsNearMeNeedsProfileBody,
          action: TextButton(
            onPressed: () => context.push(RoutePaths.fitProfile),
            child: Text(l10n.fitAddProfileShort),
          ),
        ),
      ReviewFilter.nearMe => _ReviewsMessage(
        icon: Icons.person_search_rounded,
        title: l10n.reviewsNearMeNoneTitle,
        message: l10n.reviewsNearMeNoneBody,
      ),
      ReviewFilter.photos => _ReviewsMessage(
        icon: Icons.photo_library_outlined,
        title: l10n.reviewsPhotosNoneTitle,
        message: l10n.reviewsPhotosNoneBody,
      ),
      ReviewFilter.all => _ReviewsMessage(
        icon: Icons.rate_review_outlined,
        title: l10n.reviewsNoneTitle,
        message: l10n.reviewsNoneBody,
      ),
    };
  }

  Future<void> _showReviewSheet(BuildContext context, String productId) =>
      showReviewComposer(
    context: context,
        askFit: true,
        onSubmit: (draft) => ref
        .read(reputationActionsProvider)
        .submitProductReview(
          productId: productId,
              rating: draft.rating,
              title: draft.title,
              body: draft.body,
              fit: draft.fit,
        ),
  );
}

/// «التقييمات», and the piece's standing under it.
///
/// The heading used to share one row with a filled «اكتبي» button, and on a
/// phone of ordinary width the two did not fit: the row overflowed and the
/// button was cut. The action has a row of its own now, below.
class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({required this.rating, required this.reviewsCount});

  final double rating;
  final int reviewsCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.reviewsSectionTitle,
          style: context.dsText.screenTitle.bold,
        ),
        if (reviewsCount > 0) ...[
          DsGaps.vXxs,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DsSpacing.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      rating >= i
                          ? Icons.star_rounded
                          : rating >= i - 0.5
                          ? Icons.star_half_rounded
                          : Icons.star_border_rounded,
                      size: DsSizes.iconSm,
                      color: colors.rating,
                    ),
                ],
              ),
              Text(
                context.l10n.productRatingSummary(
                  rating.toStringAsFixed(1),
                  reviewsCount,
                ),
                style: context.dsText.caption,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// What she can do about reviewing this piece, said before she starts.
///
/// The page offered «اكتبي» to everyone, let her fill in the stars, the words
/// and her photographs, and only then reported that reviews are for women who
/// received the piece. Now the answer comes first: the button when she may,
/// the way in when she is a guest, and a plain sentence when she may not yet
/// or already has.
class _ReviewAction extends ConsumerWidget {
  const _ReviewAction({required this.productId, required this.onWrite});

  final String productId;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final eligibility = ref.watch(productReviewEligibilityProvider(productId));

    return eligibility.when(
      // Nothing rather than a spinner: the reviews below are what she came
      // for, and the action settles in a moment.
      loading: () => const SizedBox.shrink(),
      // The rule still holds on the server; if the question could not be
      // asked, the button is offered and the server's answer is shown.
      error: (_, _) => _WriteButton(onPressed: onWrite),
      data: (answer) {
        if (answer.canReview) return _WriteButton(onPressed: onWrite);
        return switch (answer.block) {
          ReviewBlock.signIn => _WriteButton(
            label: l10n.reviewsSignInToWrite,
            icon: Icons.login_rounded,
            onPressed: () => requireAuthenticatedUser(
              context,
              ref,
              title: l10n.reviewsSignInToWrite,
              message: l10n.reviewsSignInToWriteBody,
              from: RoutePaths.productDetailsOf(productId),
            ),
          ),
          ReviewBlock.alreadyReviewed => _ReviewsMessage(
            icon: Icons.check_circle_outline_rounded,
            title: answer.myReview?.status == 'pending'
                ? l10n.reviewsYoursPendingTitle
                : l10n.reviewsYoursPublishedTitle,
            message: answer.myReview?.status == 'pending'
                ? l10n.reviewsYoursPendingBody
                : l10n.reviewsYoursPublishedBody,
          ),
          ReviewBlock.notDelivered || null => _ReviewsMessage(
            icon: Icons.local_shipping_outlined,
            title: l10n.reviewsAfterDeliveryTitle,
            message: l10n.reviewsAfterDeliveryBody,
          ),
        };
      },
    );
  }
}

class _WriteButton extends StatelessWidget {
  const _WriteButton({required this.onPressed, this.label, this.icon});

  final VoidCallback onPressed;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DsButton(
      label: label ?? context.l10n.reviewsWriteAction,
      icon: icon ?? Icons.edit_outlined,
      variant: label == null
          ? DsButtonVariant.primary
          : DsButtonVariant.secondary,
      size: DsButtonSize.md,
      onPressed: onPressed,
    );
  }
}

class _ReviewsMessage extends StatelessWidget {
  const _ReviewsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.dsText.body.semibold),
                Text(
                  message,
                  style: context.dsText.body.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
