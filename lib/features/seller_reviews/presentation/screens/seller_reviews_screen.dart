import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_reviews/domain/entities/seller_review.dart';
import 'package:reem/features/seller_reviews/presentation/providers/seller_reviews_provider.dart';
import 'package:reem/features/seller_reviews/presentation/widgets/seller_review_card.dart';

/// What people are saying, and her answer to it.
///
/// A seller could read every review of her goods and answer none of them — the
/// review models had nowhere to put a reply — so the only remedy for an unfair
/// one was asking a moderator to take it down. On a marketplace the reply
/// matters more than the rating: a customer reading «القياس صغير» learns
/// something different when «صحيح، الموديل ضيّق» sits underneath it.
///
/// The list is sorted worst-and-unanswered first, because that is the order a
/// shopkeeper would work it, not the order the rows were written.
class SellerReviewsScreen extends ConsumerWidget {
  const SellerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerReviewsNotifierProvider);
    final notifier = ref.read(sellerReviewsNotifierProvider.notifier);
    final l10n = context.l10n;

    ref.listen(sellerReviewsNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    final rows = _ordered(state.desk.reviews);

    return ReemScrollPage(
      onRefresh: notifier.refresh,
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        PremiumAppBar(title: l10n.sellerReviewsTitle, showBack: true),
        SliverToBoxAdapter(
          child: _FilterBar(
            unansweredOnly: state.unansweredOnly,
            unanswered: state.desk.unanswered,
            onSelect: notifier.setUnansweredOnly,
          ),
        ),

        if (state.isInitialLoading)
          const SliverToBoxAdapter(child: _Skeleton())
        else if (rows.isEmpty && state.error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                message: state.error ?? l10n.reviewsFailed,
                onRetry: notifier.refresh,
              ),
            ),
          )
        else if (rows.isEmpty)
          SliverToBoxAdapter(child: _Empty(unansweredOnly: state.unansweredOnly))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.sm,
              DsSpacing.lg,
              140,
            ),
            sliver: SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.md),
              itemBuilder: (context, index) => SellerReviewCard(
                review: rows[index],
                isBusy: state.replyingTo == rows[index].id,
                onReply: () => _openReply(context, ref, rows[index]),
              ),
            ),
          ),
      ],
    );
  }

  /// Unanswered complaints first, then unanswered praise, then the rest —
  /// each group newest first. The server returns them by date; this is the
  /// order she would actually work them in.
  List<SellerReviewItem> _ordered(List<SellerReviewItem> reviews) {
    int rank(SellerReviewItem review) {
      if (review.needsAttention) return 0;
      if (!review.isAnswered) return 1;
      return 2;
    }

    return [...reviews]..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> _openReply(
    BuildContext context,
    WidgetRef ref,
    SellerReviewItem review,
  ) async {
    final controller = TextEditingController(text: review.reply ?? '');
    final l10n = context.l10n;

    final submitted = await DsBottomSheet.show<String>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: review.isAnswered
            ? l10n.reviewsEditReply
            : l10n.reviewsReplyAction,
        subtitle: l10n.reviewsReplyHint,
        child: StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final text = controller.text.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsInputField(
                  controller: controller,
                  label: l10n.reviewsReplyField,
                  maxLines: 4,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: DsSpacing.md),
                DsButton(
                  label: l10n.reviewsReplyAction,
                  icon: Icons.reply_rounded,
                  onPressed: text.isEmpty
                      ? null
                      : () => Navigator.of(sheetContext).pop(text),
                ),
                // Taking a reply down is her own to do. A sentence written in
                // anger should not need a moderator to unpublish.
                if (review.isAnswered) ...[
                  const SizedBox(height: DsSpacing.sm),
                  DsButton(
                    label: l10n.reviewsDeleteReply,
                    variant: DsButtonVariant.danger,
                    onPressed: () => Navigator.of(sheetContext).pop(''),
                  ),
                ],
                const SizedBox(height: DsSpacing.sm),
                DsButton(
                  label: l10n.cancel,
                  variant: DsButtonVariant.ghost,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            );
          },
        ),
      ),
    );

    controller.dispose();
    if (submitted == null || !context.mounted) return;

    final error = await ref
        .read(sellerReviewsNotifierProvider.notifier)
        .reply(review, submitted);
    if (error != null || !context.mounted) return;

    DsSnackbar.show(
      context,
      message: submitted.isEmpty
          ? l10n.reviewsReplyRemoved
          : l10n.reviewsReplied,
      type: DsSnackbarType.success,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.unansweredOnly,
    required this.unanswered,
    required this.onSelect,
  });

  final bool unansweredOnly;
  final int unanswered;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: palette.primarySoft,
      backgroundColor: palette.surface,
      side: BorderSide(color: selected ? palette.primary : palette.line),
      labelStyle: selected
                ? context.dsText.tab.bold.tint(palette.primary)
                : context.dsText.tab.medium.tint(palette.ink),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          chip(l10n.reviewsFilterAll, !unansweredOnly, () => onSelect(false)),
          const SizedBox(width: DsSpacing.sm),
          chip(
            unanswered == 0
                ? l10n.reviewsFilterUnanswered
                : '${l10n.reviewsFilterUnanswered} · $unanswered',
            unansweredOnly,
            () => onSelect(true),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.unansweredOnly});

  final bool unansweredOnly;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: DsRadius.borderXl,
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              unansweredOnly
                  ? Icons.check_circle_outline_rounded
                  : Icons.reviews_outlined,
              size: 36,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            unansweredOnly ? l10n.reviewsEmptyUnanswered : l10n.reviewsEmptyAll,
            textAlign: TextAlign.center,
            style: context.dsText.cardTitle.bold.tint(palette.ink),
          ),
          if (!unansweredOnly) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              l10n.reviewsEmptyAllBody,
              textAlign: TextAlign.center,
              style: context.dsText.body.tint(palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            DsSkeleton.box(height: 180, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 180, borderRadius: DsRadius.lg),
          ],
        ),
      ),
    );
  }
}
