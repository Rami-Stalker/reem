import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/social/domain/entities/content_comment.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';

/// The comment thread for one piece, as a sheet.
///
/// Returns the **net change** in the comment count — adds minus deletes — so
/// the card underneath can update its tally without refetching the feed. The
/// old post card read an immutable `Post` and its counter never moved, which
/// was one of the client's reported defects.
Future<int> showContentComments(
  BuildContext context, {
  required String contentId,
}) async {
  final result = await DsBottomSheet.show<int>(
    context,
    builder: (_) => _ContentCommentsSheet(contentId: contentId),
  );
  return result ?? 0;
}

class _ContentCommentsSheet extends ConsumerStatefulWidget {
  const _ContentCommentsSheet({required this.contentId});

  final String contentId;

  @override
  ConsumerState<_ContentCommentsSheet> createState() =>
      _ContentCommentsSheetState();
}

class _ContentCommentsSheetState extends ConsumerState<_ContentCommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await ref
        .read(contentCommentsProvider(widget.contentId).notifier)
        .submit(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentCommentsProvider(widget.contentId));
    final notifier = ref.read(
      contentCommentsProvider(widget.contentId).notifier,
    );
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    // The net change is handed back through the pop result, so the card
    // beneath can keep its tally without refetching the feed.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(state.netChange);
      },
      child: DsSheetScaffold(
        title: context.l10n.comments,
        scrollable: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: switch (state) {
                _ when state.isLoading => const Padding(
                  padding: EdgeInsets.all(DsSpacing.xl),
                  child: DsLoadingIndicator(),
                ),
                _ when state.error != null => DsErrorState(
                  message: state.error,
                  onRetry: notifier.load,
                ),
                _ when state.comments.isEmpty => DsEmptyState(
                  icon: Icons.mode_comment_outlined,
                  title: context.l10n.noCommentsYet,
                ),
                _ => ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.md,
                    vertical: DsSpacing.sm,
                  ),
                  itemCount: state.comments.length,
                  separatorBuilder: (_, _) => DsGaps.vSm,
                  itemBuilder: (_, index) {
                    final comment = state.comments[index];
                    return _CommentTile(
                      comment: comment,
                      canRemove: comment.user.id == me,
                      onReply: () {
                        notifier.replyTo(comment);
                        _focus.requestFocus();
                      },
                      onRemove: () => notifier.remove(comment),
                      onShowReplies: () => notifier.loadReplies(comment.id),
                      currentUserId: me,
                    );
                  },
                ),
              },
            ),
            if (state.replyingTo != null)
              _ReplyingBanner(
                name: state.replyingTo!.user.name,
                onCancel: () => notifier.replyTo(null),
              ),
            _Composer(
              controller: _controller,
              focusNode: _focus,
              isSubmitting: state.isSubmitting,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canRemove,
    required this.onReply,
    required this.onRemove,
    required this.onShowReplies,
    this.currentUserId,
    this.isReply = false,
  });

  final ContentComment comment;
  final bool canRemove;
  final VoidCallback onReply;
  final VoidCallback onRemove;
  final VoidCallback onShowReplies;
  final String? currentUserId;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: isReply ? DsSpacing.xl : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsAvatar(
                imageUrl: comment.user.imageUrl,
                name: comment.user.name,
                size: isReply ? DsSizes.avatarXs : DsSizes.avatarSm,
              ),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.tileTitle,
                          ),
                        ),
                        DsGaps.hXs,
                        Text(
                          formatRelativeTime(context.l10n, comment.createdAt),
                          style: context.dsText.micro.tint(c.onSurfaceVariant),
                        ),
                      ],
                    ),
                    DsGaps.vXxs,
                    Text(comment.body, style: context.dsText.body),
                    DsGaps.vXxs,
                    Row(
                      children: [
                        if (!isReply)
                          GestureDetector(
                            onTap: onReply,
                            child: Text(
                              context.l10n.contentReply,
                              style: context.dsText.micro.tint(c.primary),
                            ),
                          ),
                        if (canRemove) ...[
                          DsGaps.hMd,
                          GestureDetector(
                            onTap: onRemove,
                            child: Text(
                              context.l10n.deleteComment,
                              style: context.dsText.micro.tint(
                                c.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty) ...[
            DsGaps.vSm,
            for (final reply in comment.replies)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                child: _CommentTile(
                  comment: reply,
                  canRemove: reply.user.id == currentUserId,
                  onReply: onReply,
                  onRemove: onRemove,
                  onShowReplies: onShowReplies,
                  currentUserId: currentUserId,
                  isReply: true,
                ),
              ),
          ],
          if (comment.hiddenReplies > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: DsSpacing.xl),
              child: GestureDetector(
                onTap: onShowReplies,
                child: Text(
                  context.l10n.contentShowReplies(comment.hiddenReplies),
                  style: context.dsText.micro.tint(c.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyingBanner extends StatelessWidget {
  const _ReplyingBanner({required this.name, required this.onCancel});

  final String name;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      color: c.surfaceVariant,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.contentReplyingTo(name),
              style: context.dsText.caption,
            ),
          ),
          DsIconButton(
            icon: Icons.close_rounded,
            tooltip: context.l10n.cancel,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: DsSpacing.md,
        right: DsSpacing.md,
        top: DsSpacing.sm,
        // Above the keyboard, not under it.
        bottom: MediaQuery.viewInsetsOf(context).bottom + DsSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: DsInputField(
              controller: controller,
              focusNode: focusNode,
              hint: context.l10n.addCommentHint,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          DsGaps.hSm,
          DsIconButton(
            icon: Icons.send_rounded,
            tooltip: context.l10n.send,
            onPressed: isSubmitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
