import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/services/share_service.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/discovery/presentation/providers/sponsored_providers.dart';
import 'package:ohara/features/profile/presentation/widgets/save_to_collection_sheet.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/social/presentation/widgets/content_card.dart';
import 'package:ohara/features/social/presentation/widgets/content_comments_sheet.dart';
import 'package:ohara/features/social/presentation/widgets/post_options_sheet.dart';
import 'package:ohara/features/social/presentation/widgets/reshare_sheet.dart';

/// A [ContentCard] that carries its own gestures.
///
/// The feeds keep likes and saves in their list notifier so a whole page moves
/// together. A woman's page is a list too, but a list of *entries* — her own
/// posts and the ones she added — and each tab reads a different endpoint, so
/// the card owns its state here: optimistic, corrected by the server's answer,
/// and put back exactly as it was on a failure.
class InteractiveContentCard extends ConsumerStatefulWidget {
  const InteractiveContentCard({
    super.key,
    required this.content,
    this.featured = false,
    this.onRemoved,
  });

  final Content content;
  final bool featured;

  /// The owning list should drop this card — she hid it, muted its author, or
  /// deleted her own post.
  final VoidCallback? onRemoved;

  @override
  ConsumerState<InteractiveContentCard> createState() =>
      _InteractiveContentCardState();
}

class _InteractiveContentCardState
    extends ConsumerState<InteractiveContentCard> {
  late Content _content = widget.content;
  bool _removed = false;

  @override
  void didUpdateWidget(InteractiveContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) _content = widget.content;
  }

  Future<bool> _signedIn() => requireAuthenticatedUser(
    context,
    ref,
    title: context.l10n.signInToInteract,
    message: context.l10n.signInToInteractBody,
  );

  Future<void> _like() async {
    if (!await _signedIn() || !mounted) return;
    final before = _content;
    final liked = !before.viewer.isLiked;
    setState(
      () => _content = before.copyWith(
        viewer: before.viewer.copyWith(isLiked: liked),
        counts: before.counts.copyWith(
          likes: (before.counts.likes + (liked ? 1 : -1)).clamp(0, 1 << 30),
        ),
      ),
    );
    final result = await ref.read(socialRepositoryProvider).react(before.id);
    if (!mounted) return;
    setState(() {
      _content = switch (result) {
        Success(:final data) => _content.copyWith(viewer: data),
        Error() => before,
      };
    });
  }

  Future<void> _save() async {
    if (!await _signedIn() || !mounted) return;
    final before = _content;
    final wasSaved = before.viewer.isSaved;
    setState(
      () => _content = before.copyWith(
        viewer: before.viewer.copyWith(isSaved: !wasSaved),
      ),
    );
    final result = await ref
        .read(socialRepositoryProvider)
        .toggleSave(before.id);
    if (!mounted) return;
    setState(() {
      _content = switch (result) {
        Success(:final data) => _content.copyWith(viewer: data),
        Error() => before,
      };
    });
    // Newly saved: ask where to keep it, the same way a product does.
    if (wasSaved || result is! Success || !mounted) return;
    await SaveToCollectionSheet.show(
      context,
      kind: SaveTargetKind.post,
      targetId: before.id,
    );
  }

  Future<void> _comment() async {
    if (!await _signedIn() || !mounted) return;
    final delta = await showContentComments(context, contentId: _content.id);
    if (!mounted || delta == 0) return;
    setState(
      () => _content = _content.copyWith(
        counts: _content.counts.copyWith(
          comments: (_content.counts.comments + delta).clamp(0, 1 << 30),
        ),
      ),
    );
  }

  Future<void> _share() async {
    final shared = await ShareService.post(
      context: context,
      postId: _content.id,
      caption: _content.caption,
      authorName: _content.author.name,
      imageUrl: _content.shareImageUrl,
    );
    if (!shared || !mounted) return;
    final result = await ref
        .read(socialRepositoryProvider)
        .recordShare(_content.id);
    if (!mounted) return;
    if (result case Success(:final data)) {
      setState(() => _content = _content.copyWith(viewer: data));
    }
  }

  Future<void> _reshare() async {
    if (!await _signedIn() || !mounted) return;
    final before = _content;
    final repository = ref.read(socialRepositoryProvider);

    Result<bool> result;
    if (before.viewer.isReshared) {
      result = await repository.unreshare(before.id);
    } else {
      final note = await showReshareSheet(context, content: before);
      if (note == null || !mounted) return;
      result = await repository.reshare(
        before.id,
        note: note.isEmpty ? null : note,
      );
    }
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        setState(
          () => _content = _content.copyWith(
            viewer: _content.viewer.copyWith(isReshared: data),
          ),
        );
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }

  void _remove() {
    if (_removed) return;
    setState(() => _removed = true);
    widget.onRemoved?.call();
  }

  void _restore() {
    if (mounted) setState(() => _removed = false);
  }

  Future<void> _menu(String? me) async {
    final content = _content;
    await showPostOptions(
      context,
      ref,
      target: PostMenuTarget(
        contentId: content.id,
        author: content.author,
        productId: content.productTags.isEmpty
            ? null
            : content.productTags.first.product.id,
        isReshared: content.viewer.isReshared,
        content: content,
      ),
      callbacks: PostMenuCallbacks(
        onEdited: content.author.id == me
            ? (updated) {
                if (mounted) setState(() => _content = updated);
              }
            : null,
        onHidden: _remove,
        onUnhidden: _restore,
        // On a woman's own page a mute does not remove her posts — muting
        // quiets feeds, and this is a page she opened on purpose.
        onToggleReshare: content.author.id == me ? null : _reshare,
        onDeleted: content.author.id == me ? _remove : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final content = _content;

    return ContentCard(
      content: content,
      featured: widget.featured,
      onOpenAuthor: (userId) =>
          unawaited(context.push(RoutePaths.userProfileOf(userId))),
      onOpenProduct: (productId) {
        // A tap on a paid post is credited to the offer that paid for it.
        if (content.sponsorship case final sponsored?) {
          ref
              .read(discoverySignalsProvider)
              .sponsoredTapped(
                offerId: sponsored.offerId,
                placement: sponsored.placement,
              );
        }
        unawaited(context.push(RoutePaths.productDetailsOf(productId)));
      },
      onLike: _like,
      onSave: _save,
      onComment: _comment,
      onShare: _share,
      onReshare: content.author.id == me ? null : _reshare,
      onMore: () => _menu(me),
    );
  }
}
