import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/open_profile.dart';
import 'package:reem/core/shared/entities/comment.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/social_posts/domain/entities/comment_thread.dart';
import 'package:reem/features/social_posts/presentation/providers/comments_state.dart';
import 'package:reem/features/social_posts/presentation/providers/social_posts_providers.dart';

/// Opens the comments for [thread] — a post's or a product's — in a
/// Reem-styled modal bottom sheet.
///
/// [onCountChanged] fires with `+1` / `-1` as the server takes a comment or a
/// deletion — the card that opened the sheet keeps its own tally, and the
/// `Post` it was built from is immutable and already stale by then. Without it
/// a shopper commented, closed the sheet, and found the counter under the post
/// still reading what it read before she typed.
Future<void> showCommentSheet(
  BuildContext context,
  CommentThread thread, {
  ValueChanged<int>? onCountChanged,
}) {
  return DsBottomSheet.show<void>(
    context,
    builder: (_) =>
        CommentSheet(thread: thread, onCountChanged: onCountChanged),
  );
}

class CommentSheet extends ConsumerStatefulWidget {
  const CommentSheet({super.key, required this.thread, this.onCountChanged});

  final CommentThread thread;

  /// Reports committed changes to the thread's size, one at a time.
  final ValueChanged<int>? onCountChanged;

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focus.unfocus();
    final added = await ref
        .read(commentsNotifierProvider(widget.thread).notifier)
        .add(text);
    if (added) widget.onCountChanged?.call(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final state = ref.watch(commentsNotifierProvider(widget.thread));
    final myId = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    // The notifier rolls a failed comment back out of the list. Without this
    // the row simply vanished and she was left wondering whether it sent.
    ref.listen(commentsNotifierProvider(widget.thread).select((s) => s.error), (
      previous,
      error,
    ) {
      if (error != null && error != previous) {
        DsSnackbar.error(context, error);
      }
    });

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xs,
              DsSpacing.lg,
              DsSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  context.l10n.comments,
                  style: context.dsText.sectionTitle.copyWith(
                    fontWeight: DsTypography.bold,
                  ),
                ),
                if (state.comments.isNotEmpty) ...[
                  const SizedBox(width: DsSpacing.xs),
                  Text(
                    '${state.comments.length}',
                    style: context.dsText.cardTitle.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: c.divider),
          Expanded(
            child: _List(
              state: state,
              myId: myId,
              thread: widget.thread,
              onCountChanged: widget.onCountChanged,
            ),
          ),
          _InputBar(
            controller: _controller,
            focusNode: _focus,
            onSend: _send,
            sending: state.isSubmitting,
          ),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({
    required this.state,
    required this.myId,
    required this.thread,
    this.onCountChanged,
  });

  final CommentsState state;
  final String? myId;
  final CommentThread thread;
  final ValueChanged<int>? onCountChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.comments.isEmpty) {
      return const _LoadingList();
    }
    if (state.isEmpty) {
      return DsEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: context.l10n.noCommentsYet,
        message: context.l10n.beTheFirstToComment,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.md,
      ),
      itemCount: state.comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.lg),
      itemBuilder: (_, i) {
        final comment = state.comments[i];
        final isMine = comment.user.id == myId;
        return _CommentTile(
          comment: comment,
          isMine: isMine,
          // Her face and her name are the way to her page — the one gesture
          // everybody tries first on a comment.
          onOpenAuthor: () => openProfileFromSheet(context, comment.user.id),
          // Deleting removes it for everyone and cannot be undone, so it is
          // confirmed. It used to fire straight off a long press, which is
          // easy to do by accident while scrolling.
          onDelete: isMine
              ? () async {
                  final confirmed = await DsDialog.confirm(
                    context,
                    title: context.l10n.deleteComment,
                    message: context.l10n.deleteCommentBody,
                    confirmLabel: context.l10n.delete,
                    cancelLabel: context.l10n.cancel,
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                  );
                  if (!confirmed || !context.mounted) return;
                  final removed = await ref
                      .read(commentsNotifierProvider(thread).notifier)
                      .remove(comment.id);
                  if (removed) onCountChanged?.call(-1);
                }
              : null,
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onOpenAuthor,
    this.onDelete,
  });

  final Comment comment;
  final bool isMine;
  final VoidCallback onOpenAuthor;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onLongPress: onDelete == null ? null : () => onDelete!(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsAvatar(
            imageUrl: comment.user.imageUrl,
            name: comment.user.name,
            size: 38,
            onTap: onOpenAuthor,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.md,
                    vertical: DsSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? c.primaryContainer : c.surfaceVariant,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(DsRadius.lg),
                      bottomLeft: Radius.circular(DsRadius.lg),
                      bottomRight: Radius.circular(DsRadius.lg),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: onOpenAuthor,
                              child: Text(
                              comment.user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.dsText.labelLarge.copyWith(
                                fontWeight: DsTypography.semiBold,
                                color: isMine
                                    ? c.onPrimaryContainer
                                    : c.onSurface,
                              ),
                            ),
                            ),
                          ),
                          if (comment.user.isVerified) ...[
                            const SizedBox(width: DsSpacing.xxs),
                            Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: c.secondary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: DsSpacing.xxs),
                      Text(
                        comment.content,
                        style: context.dsText.body.copyWith(
                          color: isMine ? c.onPrimaryContainer : c.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // A "Reply" label and a heart used to sit here. Neither did
                // anything — there is no comment threading and no comment
                // like on the server — so they were decoration that read as
                // broken. The timestamp is the only true thing in this row.
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: DsSpacing.sm,
                    top: DsSpacing.xxs,
                  ),
                  child: Row(
                    children: [
                      Text(
                        formatRelativeTime(context.l10n, comment.createdAt),
                        style: context.dsText.caption.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      if (isMine && onDelete != null) ...[
                        const SizedBox(width: DsSpacing.md),
                        GestureDetector(
                          onTap: () => onDelete!(),
                          child: Text(
                            context.l10n.delete,
                            style: context.dsText.caption.copyWith(
                              color: c.error,
                              fontWeight: DsTypography.semiBold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.md,
        ),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.lg),
        itemBuilder: (_, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DsSkeleton.circle(size: 38),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  DsSkeleton.line(width: 100),
                  SizedBox(height: DsSpacing.xs),
                  DsSkeleton.line(width: double.infinity),
                  SizedBox(height: DsSpacing.xxs),
                  DsSkeleton.line(width: 180),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final user = ref.watch(authNotifierProvider.select((s) => s.user));

    // The sheet is opened behind an auth gate, so this is the rare case: her
    // session expired while it was open. A composer that posts into a 401 is
    // worse than one that says why it is closed.
    if (user == null) {
      return Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(DsSpacing.md),
            child: Text(
              context.l10n.signInToComment,
              textAlign: TextAlign.center,
              style: context.dsText.cardSubtitle.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.md,
            DsSpacing.sm,
            DsSpacing.md,
            DsSpacing.sm,
          ),
          child: Row(
            children: [
              DsAvatar(imageUrl: user.imageUrl, name: user.name, size: 36),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: context.l10n.writeComment,
                    filled: true,
                    fillColor: c.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.md,
                      vertical: DsSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: DsRadius.borderPill,
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: DsRadius.borderPill,
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: DsRadius.borderPill,
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DsSpacing.xs),
              sending
                  ? const Padding(
                      padding: EdgeInsets.all(DsSpacing.sm),
                      child: DsLoadingIndicator.inline(),
                    )
                  : DsIconButton(
                      icon: Icons.send_rounded,
                      tooltip: context.l10n.send,
                      variant: DsIconButtonVariant.primary,
                      size: 44,
                      onPressed: onSend,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
