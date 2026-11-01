import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_message.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_aura.dart';
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
        StylistAppear(
          child: _Bubble(message: message, failed: failed, onRetry: onRetry),
        ),
        if (message.outfit != null) ...[
          DsGaps.vSm,
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
          DsGaps.vSm,
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
    final maxWidth = MediaQuery.sizeOf(context).width * (isUser ? 0.78 : 0.74);

    const big = Radius.circular(DsRadius.xl);
    const tail = Radius.circular(DsRadius.xs);
    // Directional, so the tail sits beside the speaker in RTL and LTR alike.
    final shape = BorderRadiusDirectional.only(
      topStart: big,
      topEnd: big,
      bottomStart: isUser ? big : tail,
      bottomEnd: isUser ? tail : big,
    );

    final text = Opacity(
      opacity: message.isPending && !failed ? 0.7 : 1,
      child: SelectableText(
        message.content,
        style: context.dsText.body
            .tint(isUser ? colors.onPrimary : colors.onSurface)
            .copyWith(height: 1.65),
      ),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: isUser ? context.ds.primaryGradient : null,
        color: isUser ? null : colors.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: shape,
        border: isUser
            ? null
            : Border.all(color: colors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: isUser ? 0.22 : 0.07),
            blurRadius: DsSpacing.lg,
            offset: const Offset(0, DsSpacing.xxs),
          ),
        ],
      ),
      child: text,
    );

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: isUser
              ? bubble
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const OharaOrb(size: 30),
                    DsGaps.hXs,
                    Flexible(child: bubble),
                  ],
                ),
        ),
        if (failed) ...[
          DsGaps.vXxs,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 13, color: colors.error),
              DsGaps.hXxs,
              Text(
                context.l10n.stylistMessageFailed,
                style: context.dsText.caption.tint(colors.errorInk),
              ),
              if (onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: Text(context.l10n.retry),
                ),
            ],
          ),
        ],
      ],
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
      // Plus room above and below for the cards' shadows, which a horizontal
      // list would otherwise cut off in a hard line.
      height: 430 + DsSpacing.md * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xxs,
          vertical: DsSpacing.md,
        ),
        itemCount: recommendations.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
        itemBuilder: (context, index) {
          final recommendation = recommendations[index];
          final card = StylistRecommendationCard(
            recommendation: recommendation,
            onTap: onProductTap == null
                ? null
                : () => onProductTap!(recommendation),
            onLike: onLike == null ? null : () => onLike!(recommendation),
            onDismiss:
                onDismiss == null ? null : () => onDismiss!(recommendation),
          );
          return StylistAppear(index: index + 1, offset: 22, child: card);
        },
      ),
    );
  }
}
