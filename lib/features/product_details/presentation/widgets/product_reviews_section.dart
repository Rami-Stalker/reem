import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/reputation/domain/entities/fit_entities.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:reem/features/reputation/presentation/widgets/product_fit_panel.dart';
import 'package:reem/features/reputation/presentation/widgets/review_card.dart';
import 'package:reem/features/reputation/presentation/widgets/review_composer.dart';

/// A product's reviews, with «تقييمات من بمقاسي» on top: how it fits, and the
/// two narrowings that matter before buying clothes — women her size, and
/// women who showed it on.
class ProductReviewsSection extends ConsumerStatefulWidget {
  const ProductReviewsSection({super.key, required this.productId});

  final String? productId;

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
        _ReviewsHeader(onWrite: () => _showReviewSheet(context, id)),
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

class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.l10n.reviewsSectionTitle,
          style: context.dsText.screenTitle.copyWith(
                fontWeight: DsTypography.bold,
              ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onWrite,
          icon: const Icon(Icons.edit_outlined),
          label: Text(context.l10n.reviewsWriteShort),
        ),
      ],
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
