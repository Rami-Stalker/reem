import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_message.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_outfit_board.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_recommendation_card.dart';

/// One turn in the transcript, with the cards it produced beneath it.
///
/// The cards live with the turn that chose them rather than in a single
/// results pane, so scrolling back shows what was recommended *at that point*
/// in the conversation instead of the latest answer pasted over the history.
class StylistMessageBubble extends StatelessWidget {
  const StylistMessageBubble({
    super.key,
    required this.message,
    this.onProductTap,
    this.onLike,
    this.onDismiss,
    this.onSaveOutfit,
    this.onOpenOutfit,
    this.failed = false,
    this.onRetry,
  });

  final StylistMessage message;
  final void Function(StylistRecommendation recommendation)? onProductTap;
  final void Function(StylistRecommendation recommendation)? onLike;
  final void Function(StylistRecommendation recommendation)? onDismiss;
  final void Function(StylistOutfit outfit)? onSaveOutfit;
  final void Function(StylistOutfit outfit)? onOpenOutfit;

  /// True when this is her turn and sending it failed.
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: message.isFromUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        _Bubble(message: message, failed: failed, onRetry: onRetry),
        if (message.outfit != null) ...[
          const SizedBox(height: DsSpacing.sm),
          StylistOutfitBoard(
            outfit: message.outfit!,
            onSave: onSaveOutfit == null
                ? null
                : () => onSaveOutfit!(message.outfit!),
            onOpen: onOpenOutfit == null
                ? null
                : () => onOpenOutfit!(message.outfit!),
            onPieceTap: (piece) {
              final product = piece.product;
              if (product == null || onProductTap == null) return;
              // Reuse the recommendation tap so a piece and a card open the
              // same way.
              final match = message.recommendations
                  .where((item) => item.product.id == product.id)
                  .firstOrNull;
              if (match != null) onProductTap!(match);
            },
          ),
        ],
        // An outfit already renders its pieces; showing them again below as a
        // rail would be the same six products twice.
        if (message.recommendations.isNotEmpty && message.outfit == null) ...[
          const SizedBox(height: DsSpacing.sm),
          _RecommendationRail(
            recommendations: message.recommendations,
            onProductTap: onProductTap,
            onLike: onLike,
            onDismiss: onDismiss,
          ),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.failed, this.onRetry});

  final StylistMessage message;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isUser = message.isFromUser;

    final background = isUser ? colors.primary : colors.surfaceElevated;
    final foreground = isUser ? colors.onPrimary : colors.onSurface;

    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.sm,
                vertical: DsSpacing.xs + DsSpacing.xxxs,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(DsRadius.lg),
                  topRight: const Radius.circular(DsRadius.lg),
                  bottomLeft: Radius.circular(isUser ? DsRadius.lg : DsRadius.xs),
                  bottomRight: Radius.circular(isUser ? DsRadius.xs : DsRadius.lg),
                ),
                border: isUser ? null : Border.all(color: colors.border),
              ),
              child: Opacity(
                opacity: message.isPending && !failed ? 0.65 : 1,
                child: Text(
                  message.content,
                  style: context.dsText.body.tint(foreground).copyWith(height: 1.55),
                ),
              ),
            ),
            if (failed) ...[
              const SizedBox(height: DsSpacing.xxs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 13, color: colors.error),
                  const SizedBox(width: DsSpacing.xxs),
                  Text(
                    context.l10n.stylistMessageFailed,
                    style: context.dsText.caption.tint(colors.errorInk),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.xs,
                        ),
                      ),
                      child: Text(context.l10n.retry),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationRail extends StatelessWidget {
  const _RecommendationRail({
    required this.recommendations,
    this.onProductTap,
    this.onLike,
    this.onDismiss,
  });

  final List<StylistRecommendation> recommendations;
  final void Function(StylistRecommendation recommendation)? onProductTap;
  final void Function(StylistRecommendation recommendation)? onLike;
  final void Function(StylistRecommendation recommendation)? onDismiss;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Sized for the tallest card the ranker can produce: a square cover, two
      // lines of title, price, seller, a three-line reason and the feedback
      // row. The card absorbs anything longer by trimming the reason.
      height: 430,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
        itemCount: recommendations.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
        itemBuilder: (context, index) {
          final recommendation = recommendations[index];
          return StylistRecommendationCard(
            recommendation: recommendation,
            onTap: onProductTap == null
                ? null
                : () => onProductTap!(recommendation),
            onLike: onLike == null ? null : () => onLike!(recommendation),
            onDismiss:
                onDismiss == null ? null : () => onDismiss!(recommendation),
          );
        },
      ),
    );
  }
}
