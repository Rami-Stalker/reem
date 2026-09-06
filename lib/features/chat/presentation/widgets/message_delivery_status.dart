import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// The tick beside a sent message.
///
/// One tick sent, two delivered, two in the brand rose once she has read it —
/// the read state was a fixed sky blue borrowed from another messenger, which
/// was the only blue anywhere in Reem.
class MessageDeliveryStatus extends StatelessWidget {
  const MessageDeliveryStatus({
    super.key,
    this.sent = true,
    this.delivered = false,
    this.seen = false,
  });

  final bool sent;
  final bool delivered;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Icon(
      delivered || seen ? Icons.done_all_rounded : Icons.check_rounded,
      size: DsSizes.iconXs,
      color: seen ? colors.primary : colors.onSurfaceVariant,
      semanticLabel: seen
          ? context.l10n.chatSeen
          : delivered
              ? context.l10n.chatDelivered
              : context.l10n.chatSent,
    );
  }
}
