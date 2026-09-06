import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/reputation/domain/entities/reputation_entities.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';

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
                  _LiveReviewCard(review: items[index]),
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
  ) async {
    final title = TextEditingController();
    final body = TextEditingController();
    var rating = 5;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.sm,
                DsSpacing.lg,
                bottom + DsSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.reviewsWriteAction,
                    style: context.dsText.sectionTitle.copyWith(
                          fontWeight: DsTypography.bold,
                        ),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  Row(
                    children: List.generate(5, (index) {
                      final selected = index < rating;
                      return IconButton(
                        tooltip: context.l10n.reviewsStarsCount(index + 1),
                        onPressed: () => setState(() => rating = index + 1),
                        icon: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: context.dsColors.warning,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: context.l10n.reviewsFieldTitle,
                      prefixIcon: Icon(Icons.short_text_rounded),
                    ),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.l10n.reviewsFieldBody,
                      prefixIcon: Icon(Icons.rate_review_outlined),
                    ),
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final result = await ref
                            .read(reputationActionsProvider)
                            .submitProductReview(
                              productId: productId,
                              rating: rating,
                              title: title.text,
                              body: body.text,
                            );
                        if (!context.mounted) return;
                        switch (result) {
                          case Success():
                            ref.invalidate(productReviewsProvider(productId));
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.reviewsSubmitted),
                              ),
                            );
                          case Error(:final failure):
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(failure.message)),
                            );
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: Text(context.l10n.reviewsSubmit),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    title.dispose();
    body.dispose();
  }
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

class _LiveReviewCard extends StatelessWidget {
  const _LiveReviewCard({required this.review});

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
