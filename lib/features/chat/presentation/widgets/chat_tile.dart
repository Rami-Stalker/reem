import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/presentation/widgets/unread_badge.dart';
import 'package:reem/l10n/app_localizations.dart';

/// One conversation in the inbox, as a letter.
///
/// An unread letter is lit three ways at once and nowhere else: a rose ribbon
/// down its leading edge, a thread round the arch portrait, and its count in a
/// wax seal. A list where every row is tinted stops distinguishing anything,
/// so a read letter is quiet paper. The context caption («بخصوص طلب») is what
/// tells her which of two conversations with the same boutique she is opening.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The person first. `title` is the *subject* the thread was opened about —
    // for an order chat the server sends "Order #REEM-…" — so preferring it
    // turned the seller's inbox into a column of order numbers with no name on
    // any of them. The subject is already carried by the caption below.
    final title = thread.peerName?.trim().isNotEmpty == true
        ? thread.peerName!
        : (thread.title.isNotEmpty ? thread.title : l10n.chatUntitled);
    final paper = isDark ? c.surfaceElevated : c.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.borderXxl,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderXxl,
            color: unread
                ? Color.alphaBlend(c.primary.withValues(alpha: 0.05), paper)
                : paper.withValues(alpha: 0.86),
            border: Border.all(
              color: unread
                  ? c.primary.withValues(alpha: 0.35)
                  : c.border.withValues(alpha: 0.6),
            ),
            boxShadow: unread ? context.shadowSoft : context.shadowXs,
          ),
          child: ClipRRect(
            borderRadius: DsRadius.borderXxl,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The ribbon.
                  AnimatedContainer(
                    duration: DsMotion.moderate,
                    width: unread ? 4 : 0,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.primary, DsColors.gold300],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpacing.md),
                      child: Row(
                        children: [
                          ArchAvatar(
                            name: title,
                            imageUrl: thread.avatarUrl.isEmpty
                                ? null
                                : thread.avatarUrl,
                            width: 50,
                            isOnline: thread.isOnline,
                            lit: unread,
                          ),
                          DsGaps.hMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.dsText.tileTitle
                                            .copyWith(
                                              fontWeight: unread
                                                  ? DsTypography.bold
                                                  : DsTypography.semiBold,
                                            ),
                                      ),
                                    ),
                                    DsGaps.hSm,
                                    Text(
                                      formatThreadStamp(l10n, thread.updatedAt),
                                      style: context.dsText.caption.copyWith(
                                        color: unread
                                            ? c.primary
                                            : c.onSurfaceVariant,
                                        fontWeight: unread
                                            ? DsTypography.semiBold
                                            : DsTypography.regular,
                                      ),
                                    ),
                                  ],
                                ),
                                DsGaps.vXxs,
                                Row(
                                  children: [
                                    Expanded(
                                      child: _Preview(
                                        thread: thread,
                                        isTyping: isTyping,
                                        unread: unread,
                                      ),
                                    ),
                                    if (unread) ...[
                                      DsGaps.hSm,
                                      UnreadBadge(count: thread.unreadCount),
                                    ],
                                  ],
                                ),
                                if (_contextLabel(l10n) case final label?) ...[
                                  DsGaps.vXs,
                                  _ContextChip(
                                    label: label,
                                    icon: _contextIcon(thread.context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  static IconData _contextIcon(ChatContext context) => switch (context) {
    ChatContext.product => Icons.shopping_bag_rounded,
    ChatContext.order => Icons.local_shipping_rounded,
    ChatContext.support => Icons.support_agent_rounded,
    ChatContext.direct => Icons.chat_bubble_rounded,
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
      return Row(
        children: [
          WaveDots(size: 5, color: c.primary),
          DsGaps.hXs,
          Flexible(
            child: Text(
              context.l10n.chatTyping,
              style: context.dsText.cardSubtitle.copyWith(
                color: c.primary,
                fontWeight: DsTypography.semiBold,
              ),
            ),
          ),
        ],
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
  const _ContextChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        color: c.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: DsRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DsSizes.iconXxs, color: c.onSecondaryContainer),
          DsGaps.hXxs,
          Text(
            label,
            style: context.dsText.caption.copyWith(
              color: c.onSecondaryContainer,
              fontWeight: DsTypography.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}
