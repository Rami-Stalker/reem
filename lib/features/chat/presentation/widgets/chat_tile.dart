import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/presentation/widgets/unread_badge.dart';
import 'package:reem/l10n/app_localizations.dart';

/// One conversation in the inbox.
///
/// Unread is carried by weight and a single badge rather than a coloured row:
/// a list where four of five rows are tinted has stopped distinguishing
/// anything. The context caption ("بخصوص طلب") is what tells her which of two
/// conversations with the same boutique she is about to open.
class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.thread,
    required this.onTap,
    this.isTyping = false,
  });

  final ChatThreadEntity thread;
  final VoidCallback onTap;

  /// Live from the socket, not from the thread payload — it is true for a few
  /// seconds at a time and never survives a reload.
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final unread = thread.hasUnread;
    // The person first. `title` is the *subject* the thread was opened about —
    // for an order chat the server sends "Order #REEM-…" — so preferring it
    // turned the seller's inbox into a column of order numbers with no name on
    // any of them, and English ones at that. The subject is already carried by
    // the caption below.
    final title = thread.peerName?.trim().isNotEmpty == true
        ? thread.peerName!
        : (thread.title.isNotEmpty ? thread.title : l10n.chatUntitled);

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      elevation: unread ? DsCardElevation.medium : DsCardElevation.low,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DsAvatar(
            imageUrl: thread.avatarUrl.isEmpty ? null : thread.avatarUrl,
            name: title,
            size: 56,
            isOnline: thread.isOnline,
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.tileTitle.copyWith(
                          fontWeight: unread
                              ? DsTypography.bold
                              : DsTypography.semiBold,
                        ),
                      ),
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    Text(
                      formatThreadStamp(l10n, thread.updatedAt),
                      style: context.dsText.caption.copyWith(
                        color: unread ? c.primary : c.onSurfaceVariant,
                        fontWeight:
                            unread ? DsTypography.semiBold : DsTypography.regular,
                      ),
                    ),
                  ],
                ),
                DsGaps.vXs,
                _Preview(thread: thread, isTyping: isTyping, unread: unread),
                if (_contextLabel(l10n) case final label?) ...[
                  DsGaps.vXs,
                  _ContextChip(label: label),
                ],
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: DsSpacing.sm),
            UnreadBadge(count: thread.unreadCount),
          ],
        ],
      ),
    );
  }

  /// A direct conversation gets no caption — the name above it already says
  /// everything, and a chip on every row would be wallpaper.
  String? _contextLabel(AppLocalizations l10n) => switch (thread.context) {
        ChatContext.product => l10n.chatContextProduct,
        ChatContext.order => l10n.chatContextOrder,
        ChatContext.support => l10n.chatContextSupport,
        ChatContext.direct => null,
      };
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.thread,
    required this.isTyping,
    required this.unread,
  });

  final ChatThreadEntity thread;
  final bool isTyping;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    if (isTyping) {
      return Text(
        context.l10n.chatTyping,
        style: context.dsText.cardSubtitle.copyWith(
          color: c.primary,
          fontWeight: DsTypography.semiBold,
        ),
      );
    }

    final preview = thread.lastMessage.trim();
    return Text(
      preview.isEmpty ? context.l10n.chatNoMessagesYet : preview,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.dsText.cardSubtitle.copyWith(
        color: preview.isEmpty
            ? c.onSurfaceVariant.withValues(alpha: 0.7)
            : (unread ? c.onSurface : c.onSurfaceVariant),
        fontWeight: unread ? DsTypography.semiBold : DsTypography.regular,
        fontStyle: preview.isEmpty ? FontStyle.italic : FontStyle.normal,
        height: 1.35,
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs, vertical: DsSpacing.xxs),
      decoration: BoxDecoration(
        color: c.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: DsRadius.borderSm,
      ),
      child: Text(
        label,
        style: context.dsText.caption.copyWith(
              color: c.onSecondaryContainer,
              fontWeight: DsTypography.semiBold,
            ),
      ),
    );
  }
}
