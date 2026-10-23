import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// One message in a conversation.
///
/// Hers ride the rose blend with a soft glow under them; the other side's are
/// frosted pearl with a hairline rim. The last bubble of a run curls into a
/// small tail on the sender's side — [tail] — so a run of messages reads as one
/// voice rather than a stack of separate cards.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.isMe,
    required this.message,
    this.tail = true,
  });

  final bool isMe;
  final String message;
  final bool tail;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      // Directional, not absolute: the sender's own bubble sits on the
      // trailing edge of the reading direction, which flips with the locale
      // instead of staying pinned to a physical side.
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DsSizes.maxFormWidth * 0.7),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            // In dark mode the theme's rose is lighter, and white words on it
            // fade; her bubble keeps the deeper blend so they stay legible.
            gradient: isMe
                ? (isDark ? DsGradients.primarySoft : context.primaryGradient)
                : null,
            color: isMe
                ? null
                : (isDark ? colors.surfaceElevated : colors.surface).withValues(
                    alpha: 0.92,
                  ),
            shape: SilkBubbleBorder(
              mine: isMe,
              tail: tail,
              side: isMe
                  ? BorderSide.none
                  : BorderSide(color: colors.border.withValues(alpha: 0.8)),
            ),
            shadows: isMe
                ? context.glowShadow(colors.primary, blur: 16, alpha: 0.22)
                : context.shadowXs,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start:
                  DsSpacing.md +
                  (!isMe && tail ? SilkBubbleBorder.tailWidth : 0),
              end:
                  DsSpacing.md +
                  (isMe && tail ? SilkBubbleBorder.tailWidth : 0),
              top: DsSpacing.sm,
              bottom: DsSpacing.sm,
            ),
            child: Text(
              message,
              style: context.dsText.body
                  .tint(isMe ? DsColors.onMedia : colors.onSurface)
                  .copyWith(height: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}
