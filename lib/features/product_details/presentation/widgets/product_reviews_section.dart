import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:reem/features/reputation/presentation/widgets/review_card.dart';
import 'package:reem/features/reputation/presentation/widgets/review_composer.dart';

class ProductReviewsSection extends ConsumerWidget {
  const ProductReviewsSection({super.key, required this.productId});

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productId;
    if (id == null || id.isEmpty) {
      return const SizedBox.shrink();
    }

    final reviews = ref.watch(productReviewsProvider(id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewsHeader(
          onWrite: () => _showReviewSheet(context, ref, id),
        ),
        const SizedBox(height: DsSpacing.lg),
        reviews.when(
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => _ReviewsMessage(
            icon: Icons.error_outline_rounded,
            title: context.l10n.reviewsUnavailable,
            message: messageOf(error),
            action: IconButton(
              tooltip: context.l10n.retry,
              onPressed: () => ref.invalidate(productReviewsProvider(id)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _ReviewsMessage(
                icon: Icons.rate_review_outlined,
                title: context.l10n.reviewsNoneTitle,
                message: context.l10n.reviewsNoneBody,
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: DsSpacing.md),
              itemBuilder: (context, index) =>
                  ReviewCard(review: items[index]),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showReviewSheet(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) => showReviewComposer(
    context: context,
    onSubmit: ({required rating, required title, required body}) => ref
        .read(reputationActionsProvider)
        .submitProductReview(
          productId: productId,
          rating: rating,
          title: title,
          body: body,
        ),
    onSubmitted: () => ref.invalidate(productReviewsProvider(productId)),
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
                Text(
                  title,
                  style: context.dsText.body.semibold,
                ),
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
