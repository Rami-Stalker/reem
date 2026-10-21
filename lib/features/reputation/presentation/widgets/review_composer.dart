import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/reputation/domain/entities/reputation_entities.dart';

/// The sheet she writes a review in — stars, a headline, a few words.
///
/// Lifted out of the product page because the seller profile needed the same
/// sheet. `ReputationActions` has had `submitSellerReview` since the module
/// landed and nothing ever called it: a shopper could review a dress and had
/// no way to say anything about the boutique that sent it. Rather than a
/// second composer that drifts from this one, the caller passes what to do
/// with the answer.
Future<void> showReviewComposer({
  required BuildContext context,
  required Future<Result<ReviewEntity>> Function({
    required int rating,
    required String title,
    required String body,
  })
  onSubmit,
  VoidCallback? onSubmitted,
}) async {
  final title = TextEditingController();
  final body = TextEditingController();
  var rating = 5;
  var submitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return StatefulBuilder(
        builder: (sheetContext, setState) {
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
                  sheetContext.l10n.reviewsWriteAction,
                  style: sheetContext.dsText.sectionTitle.copyWith(
                    fontWeight: DsTypography.bold,
                  ),
                ),
                const SizedBox(height: DsSpacing.md),
                Row(
                  children: List.generate(5, (index) {
                    final selected = index < rating;
                    return IconButton(
                      tooltip: sheetContext.l10n.reviewsStarsCount(index + 1),
                      onPressed: submitting
                          ? null
                          : () => setState(() => rating = index + 1),
                      icon: Icon(
                        selected
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: sheetContext.dsColors.warning,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: DsSpacing.sm),
                DsInputField(
                  controller: title,
                  enabled: !submitting,
                  label: sheetContext.l10n.reviewsFieldTitle,
                  prefixIcon: const Icon(Icons.short_text_rounded),
                ),
                const SizedBox(height: DsSpacing.sm),
                DsInputField(
                  controller: body,
                  minLines: 3,
                  maxLines: 5,
                  enabled: !submitting,
                  label: sheetContext.l10n.reviewsFieldBody,
                  prefixIcon: const Icon(Icons.rate_review_outlined),
                ),
                const SizedBox(height: DsSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : () async {
                            setState(() => submitting = true);
                            final result = await onSubmit(
                              rating: rating,
                              title: title.text,
                              body: body.text,
                            );
                            if (!sheetContext.mounted) return;
                            switch (result) {
                              case Success():
                                Navigator.of(sheetContext).pop();
                                onSubmitted?.call();
                                DsSnackbar.show(
                                  context,
                                  message: context.l10n.reviewsSubmitted,
                                  type: DsSnackbarType.success,
                                );
                              case Error(:final failure):
                                setState(() => submitting = false);
                                DsSnackbar.show(
                                  sheetContext,
                                  message: failure.message,
                                  type: DsSnackbarType.error,
                                );
                            }
                          },
                    icon: const Icon(Icons.send_rounded),
                    label: Text(sheetContext.l10n.reviewsSubmit),
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
