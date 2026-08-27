import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/shared/entities/comment.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/social_posts/presentation/providers/comments_state.dart';
import 'package:reem/features/social_posts/presentation/providers/social_posts_providers.dart';

/// Opens the comments for [postId] in a Reem-styled modal bottom sheet.
Future<void> showCommentSheet(BuildContext context, String postId) {
  return DsBottomSheet.show<void>(
    context,
    builder: (_) => CommentSheet(postId: postId),
  );
}

class CommentSheet extends ConsumerStatefulWidget {
  const CommentSheet({super.key, required this.postId});

  final String postId;

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
    await ref.read(commentsNotifierProvider(widget.postId).notifier).add(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final state = ref.watch(commentsNotifierProvider(widget.postId));
    final myId = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg, DsSpacing.xs, DsSpacing.lg, DsSpacing.sm),
            child: Row(
              children: [
                Text('Comments',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: DsTypography.bold)),
                if (state.comments.isNotEmpty) ...[
                  const SizedBox(width: DsSpacing.xs),
                  Text('${state.comments.length}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: c.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: c.divider),
          Expanded(child: _List(state: state, myId: myId, postId: widget.postId)),
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
  const _List({required this.state, required this.myId, required this.postId});

  final CommentsState state;
  final String? myId;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.comments.isEmpty) {
      return const _LoadingList();
    }
    if (state.isEmpty) {
      return const DsEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No comments yet',
        message: 'Be the first to share what you think.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg, vertical: DsSpacing.md),
      itemCount: state.comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.lg),
      itemBuilder: (_, i) {
        final comment = state.comments[i];
        final isMine = comment.user.id == myId;
        return _CommentTile(
          comment: comment,
          isMine: isMine,
          onDelete: isMine
              ? () => ref
                  .read(commentsNotifierProvider(postId).notifier)
                  .remove(comment.id)
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
    this.onDelete,
  });

  final Comment comment;
  final bool isMine;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: onDelete,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsAvatar(
            imageUrl: comment.user.imageUrl,
            name: comment.user.name,
            size: 38,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.md, vertical: DsSpacing.sm),
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
                            child: Text(
                              comment.user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: DsTypography.semiBold,
                                color: isMine
                                    ? c.onPrimaryContainer
                                    : c.onSurface,
                              ),
                            ),
                          ),
                          if (comment.user.isVerified) ...[
                            const SizedBox(width: DsSpacing.xxs),
                            Icon(Icons.verified_rounded,
                                size: 13, color: c.secondary),
                          ],
                        ],
                      ),
                      const SizedBox(height: DsSpacing.xxs),
                      Text(
                        comment.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              isMine ? c.onPrimaryContainer : c.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      start: DsSpacing.sm, top: DsSpacing.xxs),
                  child: Row(
                    children: [
                      Text(_ago(comment.createdAt),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: c.onSurfaceVariant)),
                      const SizedBox(width: DsSpacing.md),
                      Text('Reply',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: c.onSurfaceVariant,
                              fontWeight: DsTypography.semiBold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.xs),
          Icon(Icons.favorite_border_rounded,
              size: 16, color: c.onSurfaceVariant),
        ],
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.lg, vertical: DsSpacing.md),
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
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              DsSpacing.md, DsSpacing.sm, DsSpacing.md, DsSpacing.sm),
          child: Row(
            children: [
              DsAvatar(imageUrl: user?.imageUrl, name: user?.name, size: 36),
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
                    hintText: 'Add a comment…',
                    filled: true,
                    fillColor: c.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.md, vertical: DsSpacing.sm),
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
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  : DsIconButton(
                      icon: Icons.send_rounded,
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
