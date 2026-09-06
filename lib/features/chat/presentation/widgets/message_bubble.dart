import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// One message in a conversation.
///
/// Her own messages ride the brand gradient; the other party's sit on a theme
/// surface. Both used a bespoke pink (`0xffFF5C8A`) and a fixed white ground,
/// which meant the thread stayed bright — and off-brand — in dark mode.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.isMe,
    required this.message,
  });

  final bool isMe;
  final String message;

  /// The tail corner is tightened on the sender's side, so the bubble points
  /// at whoever said it.
  static const Radius _tail = Radius.circular(DsRadius.sm);
  static const Radius _round = Radius.circular(DsRadius.xxl);

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Align(
      // Directional, not absolute: the sender's own bubble sits on the
      // trailing edge of the reading direction, which flips with the locale
      // instead of staying pinned to a physical side.
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: DsSizes.maxFormWidth * 0.7),
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: isMe ? context.primaryGradient : null,
          color: isMe ? null : colors.surfaceElevated,
          border: isMe ? null : Border.all(color: colors.border),
          borderRadius: BorderRadiusDirectional.only(
            topStart: _round,
            topEnd: _round,
            bottomStart: isMe ? _round : _tail,
            bottomEnd: isMe ? _tail : _round,
          ),
        ),
        child: Text(
          message,
          style: context.dsText.body
              .tint(isMe ? DsColors.onMedia : colors.onSurface)
              .copyWith(height: 1.6),
        ),
      ),
    );
  }
}
