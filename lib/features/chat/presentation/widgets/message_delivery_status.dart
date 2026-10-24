import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';

/// The tick beside a sent message.
///
/// A clock while it is on its way, one tick sent, two delivered, two in the
/// brand rose once she has read it, and a warning when it did not go — the
/// read state was a fixed sky blue borrowed from another messenger, which was
/// the only blue anywhere in Ohara.
class MessageDeliveryStatus extends StatelessWidget {
  const MessageDeliveryStatus({
    super.key,
    this.sent = true,
    this.delivered = false,
    this.seen = false,
    this.pending = false,
    this.failed = false,
  });

  final bool sent;
  final bool delivered;
  final bool seen;
  final bool pending;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    if (failed) {
      return Icon(
        Icons.error_outline_rounded,
        size: DsSizes.iconXs,
        color: colors.error,
        semanticLabel: l10n.chatSendFailed,
      );
    }
    if (pending) {
      return Icon(
        Icons.schedule_rounded,
        size: DsSizes.iconXs,
        color: colors.onSurfaceVariant,
        semanticLabel: l10n.chatSending,
      );
    }
    return Icon(
      delivered || seen ? Icons.done_all_rounded : Icons.check_rounded,
      size: DsSizes.iconXs,
      color: seen ? colors.primary : colors.onSurfaceVariant,
      semanticLabel: seen
          ? l10n.chatSeen
          : delivered
              ? l10n.chatDelivered
              : l10n.chatSent,
    );
  }
}
