import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/open_route.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';

/// The head of one conversation: who she is talking to, and whether they are
/// there right now.
///
/// [thread] is null only while the header is still loading, or when the server
/// refused to describe the conversation. Both draw the same skeleton rather
/// than a placeholder name — inventing an identity here is how the old build
/// told every shopper she was talking to "Lujain Fashion".
class ChatAppBar extends StatelessWidget {
  const ChatAppBar({
    super.key,
    this.thread,
    this.isPeerTyping = false,
    this.onOpenSharedMedia,
    this.onOpenProfile,
  });

  final ChatThreadEntity? thread;
  final bool isPeerTyping;

  /// Opens the conversation's shared photographs.
  final VoidCallback? onOpenSharedMedia;

  /// Opens the boutique's storefront, when the conversation has one.
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final title = _title(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.sm,
        DsSpacing.md,
        DsSpacing.md,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: c.divider.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          DsIconButton(
            tooltip: 'رجوع',
            icon: Directionality.of(context) == TextDirection.rtl
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            // A conversation is opened from the inbox, from a product, and
            // from a notification tap — and only the first of those leaves a
            // route to pop, so the arrow needs the shared fallback.
            onPressed: () => popOrHome(context),
          ),
          const SizedBox(width: DsSpacing.sm),
          DsAvatar(
            imageUrl: (thread?.avatarUrl.isEmpty ?? true)
                ? null
                : thread!.avatarUrl,
            name: title,
            size: 46,
            isOnline: thread?.isOnline ?? false,
            onTap: onOpenProfile,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.tileTitle
                        .copyWith(fontWeight: DsTypography.bold),
                  ),
                  DsGaps.vXxxs,
                  Text(
                    _presence(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.copyWith(
                      color: isPeerTyping || (thread?.isOnline ?? false)
                          ? c.success
                          : c.onSurfaceVariant,
                      fontWeight: isPeerTyping
                          ? DsTypography.semiBold
                          : DsTypography.regular,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onOpenSharedMedia != null)
            DsIconButton(
              icon: Icons.photo_library_outlined,
              tooltip: l10n.chatSharedMedia,
              onPressed: onOpenSharedMedia,
            ),
        ],
      ),
    );
  }

  String _title(BuildContext context) {
    final current = thread;
    if (current == null) return context.l10n.chatUntitled;
    // Whom she is talking to, not what about — the same order as the inbox.
    final peer = current.peerName?.trim();
    if (peer != null && peer.isNotEmpty) return peer;
    if (current.title.isNotEmpty) return current.title;
    return context.l10n.chatUntitled;
  }

  /// Typing beats presence, presence beats a last-seen stamp, and a thread we
  /// could not load says nothing at all rather than guessing "Online".
  String _presence(BuildContext context) {
    final l10n = context.l10n;
    if (isPeerTyping) return l10n.chatTyping;
    final current = thread;
    if (current == null) return '';
    if (current.isOnline) return l10n.chatOnlineNow;
    final lastSeen = current.lastSeenAt;
    if (lastSeen == null) return '';
    return l10n.chatLastSeen(formatRelativeTime(l10n, lastSeen));
  }
}
