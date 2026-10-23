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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final live = isPeerTyping || (thread?.isOnline ?? false);

    // A capsule floating over the conversation rather than a bar across it:
    // the thread runs up behind the header instead of stopping at a ruled
    // line, and the person she is writing to sits in the arch like everyone
    // else on Reem.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.xs,
        DsSpacing.md,
        DsSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DsSpacing.xxs,
          DsSpacing.xs,
          DsSpacing.sm,
          DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderXxl,
          color: (isDark ? c.surfaceElevated : c.surface).withValues(
            alpha: 0.9,
          ),
          border: Border.all(color: c.border.withValues(alpha: 0.7)),
          boxShadow: context.shadowSoft,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.back,
              icon: Icon(
                DsIcons.back,
                size: DsSizes.iconSm,
                color: c.onSurface,
              ),
              // A conversation is opened from the inbox, from a product, and
              // from a notification tap — and only the first of those leaves a
              // route to pop, so the arrow needs the shared fallback.
              onPressed: () => popOrHome(context),
            ),
            ArchAvatar(
              name: title,
              imageUrl: (thread?.avatarUrl.isEmpty ?? true)
                  ? null
                  : thread!.avatarUrl,
              width: 38,
              isOnline: thread?.isOnline ?? false,
              onTap: onOpenProfile,
            ),
            DsGaps.hSm,
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
                      style: context.dsText.tileTitle.copyWith(
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                    if (_presence(context) case final presence
                        when presence.isNotEmpty)
                      Row(
                        children: [
                          if (isPeerTyping) ...[
                            WaveDots(size: 4, color: c.success),
                            DsGaps.hXxs,
                          ],
                          Flexible(
                            child: Text(
                              presence,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.dsText.caption.copyWith(
                                color: live ? c.success : c.onSurfaceVariant,
                                fontWeight: isPeerTyping
                                    ? DsTypography.semiBold
                                    : DsTypography.regular,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (onOpenSharedMedia != null)
              IconButton(
                icon: Icon(
                  Icons.photo_library_rounded,
                  size: DsSizes.iconSm,
                  color: c.primary,
                ),
                tooltip: l10n.chatSharedMedia,
                onPressed: onOpenSharedMedia,
              ),
          ],
        ),
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
