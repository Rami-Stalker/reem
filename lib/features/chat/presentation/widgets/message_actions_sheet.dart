import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';

/// What a long press on a message offers.
enum MessageAction { copy, resend, deleteForMe, deleteForEveryone, report }

/// How long a message of hers can still be taken back from both sides. The
/// server holds the same line and has the last word.
const Duration kDeleteForEveryoneWindow = Duration(hours: 48);

/// The long-press menu on a chat message.
///
/// Only what applies is offered: copy for a message with words in it, «حذف
/// عند الجميع» for her own and only while it can still be taken back, a
/// report for the other side's. Through [DsBottomSheet.choose], so it is an
/// action sheet on an iPhone and a list on Android.
abstract final class MessageActionsSheet {
  static List<MessageAction> actionsFor(
    ChatMessageEntity message, {
    DateTime? now,
  }) {
    if (message.isDeleted) return const [MessageAction.deleteForMe];
    final recent = (now ?? DateTime.now()).difference(message.sentAt) <
        kDeleteForEveryoneWindow;
    return [
      if (message.content.trim().isNotEmpty) MessageAction.copy,
      if (message.isFailed) MessageAction.resend,
      MessageAction.deleteForMe,
      if (message.isMine && !message.isLocal && recent)
        MessageAction.deleteForEveryone,
      if (!message.isMine) MessageAction.report,
    ];
  }

  static Future<MessageAction?> show(
    BuildContext context,
    ChatMessageEntity message,
  ) {
    final l10n = context.l10n;
    return DsBottomSheet.choose<MessageAction>(
      context,
      choices: [
        for (final action in actionsFor(message))
          switch (action) {
            MessageAction.copy => DsSheetChoice(
              value: action,
              label: l10n.copy,
              icon: Icons.copy_rounded,
            ),
            MessageAction.resend => DsSheetChoice(
              value: action,
              label: l10n.chatResend,
              icon: Icons.refresh_rounded,
            ),
            MessageAction.deleteForMe => DsSheetChoice(
              value: action,
              label: l10n.chatDeleteForMe,
              icon: Icons.delete_outline_rounded,
              destructive: true,
            ),
            MessageAction.deleteForEveryone => DsSheetChoice(
              value: action,
              label: l10n.chatDeleteForEveryone,
              icon: Icons.delete_sweep_outlined,
              destructive: true,
            ),
            MessageAction.report => DsSheetChoice(
              value: action,
              label: l10n.chatReportMessage,
              icon: Icons.flag_outlined,
            ),
          },
      ],
    );
  }

  /// Why she is reporting it, in the server's vocabulary.
  static Future<String?> askReportReason(BuildContext context) {
    final l10n = context.l10n;
    return DsBottomSheet.choose<String>(
      context,
      title: l10n.reportTitle,
      message: l10n.reportSubtitle,
      choices: [
        DsSheetChoice(value: 'SPAM', label: l10n.reportReasonSpam),
        DsSheetChoice(value: 'HARASSMENT', label: l10n.reportReasonHarassment),
        DsSheetChoice(value: 'FRAUD', label: l10n.chatReportFraud),
        DsSheetChoice(value: 'OTHER', label: l10n.reportReasonOther),
      ],
    );
  }
}

/// «تم حذف هذه الرسالة» in the place of a message taken back.
class DeletedMessageBubble extends StatelessWidget {
  const DeletedMessageBubble({super.key, required this.isMe});

  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_rounded,
            size: DsSizes.iconSm,
            color: colors.onSurfaceVariant,
          ),
          DsGaps.hXs,
          Flexible(
            child: Text(
              isMe ? l10n.chatMessageDeletedByMe : l10n.chatMessageDeleted,
              style: context.dsText.bodySmall.tint(
                colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
