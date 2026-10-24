import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/presentation/providers/content_feed_notifier.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/widgets/content_audience_sheet.dart';
import 'package:reem/features/social/presentation/widgets/content_comments_sheet.dart';
import 'package:reem/features/social/presentation/widgets/post_options_sheet.dart';
import 'package:reem/features/social/presentation/widgets/reshare_sheet.dart';

/// Reels: one clip at a time, full bleed, with the way to buy on the glass.
///
/// The commerce case is what makes this different from a video feed. A reel
/// that cannot be bought from is entertainment; the shop plate sits over the
/// bottom third, where her thumb already is, and the tap goes straight to the
/// boutique's product page.
///
/// Everything a card in the feed can do, a reel can do too: the «…» menu
/// (edit or delete her own, hide, mute, copy the link, report somebody
/// else's), a double tap to like, and «شوهدت من قبل» on her own clips.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final _pages = PageController();

  /// Reels already counted as viewed in this visit. A swipe back to one she
  /// has seen is not a second view, and the server agrees — this only saves
  /// the request.
  final _viewed = <String>{};
  bool _firstViewSent = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ContentFeedNotifier get _notifier =>
      ref.read(contentFeedProvider(SocialFeedKind.reels).notifier);

  Future<bool> _signedIn() => requireAuthenticatedUser(
    context,
    ref,
    title: context.l10n.signInToInteract,
    message: context.l10n.signInToInteractBody,
  );

  /// The seller's views number. Signed-out visitors are not counted: the
  /// ledger keys a view by the woman, and there is nobody to key it by.
  void _markViewed(Content reel) {
    if (!_viewed.add(reel.id)) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    unawaited(ref.read(socialRepositoryProvider).recordEvent(reel.id, 'VIEW'));
  }

  Future<void> _like(Content reel, {bool onlyAdd = false}) async {
    if (!await _signedIn()) return;
    // A double tap only ever likes — tapping twice on a reel she already
    // liked must not take the like back.
    if (onlyAdd && reel.viewer.isLiked) return;
    await _notifier.toggleLike(reel.id);
  }

  Future<void> _save(Content reel) async {
    if (!await _signedIn()) return;
    await _notifier.toggleSave(reel.id);
  }

  Future<void> _comment(Content reel) async {
    final delta = await showContentComments(context, contentId: reel.id);
    _notifier.adjustComments(reel.id, delta);
  }

  Future<void> _share(Content reel) async {
    final shared = await ShareService.post(
      context: context,
      postId: reel.id,
      caption: reel.caption,
      authorName: reel.author.name,
      imageUrl: reel.shareImageUrl,
    );
    if (shared && ref.read(authNotifierProvider).isAuthenticated) {
      await _notifier.recordShare(reel.id);
    }
  }

  Future<void> _reshare(Content reel) async {
    if (!await _signedIn() || !mounted) return;
    if (reel.viewer.isReshared) {
      await _notifier.toggleReshare(reel.id);
      return;
    }
    final note = await showReshareSheet(context, content: reel);
    if (note == null) return;
    await _notifier.toggleReshare(reel.id, note: note.isEmpty ? null : note);
  }

  Future<void> _more(Content reel, String? me) async {
    var removed = <(int, Content)>[];
    final mine = reel.author.id == me;
    await showPostOptions(
      context,
      ref,
      target: PostMenuTarget(
        contentId: reel.id,
        author: reel.author,
        productId: reel.primaryTag?.product.id,
        isReshared: reel.viewer.isReshared,
        content: reel,
      ),
      callbacks: PostMenuCallbacks(
        onEdited: mine ? _notifier.replace : null,
        onDeleted: mine ? () => _notifier.drop(reel.id) : null,
        onHidden: () =>
            removed = _notifier.removeWhere((item) => item.id == reel.id),
        onUnhidden: () => _notifier.restore(removed),
        onMuted: () => removed = _notifier.removeWhere(
          (item) => item.author.id == reel.author.id,
        ),
        onUnmuted: () => _notifier.restore(removed),
        onToggleReshare: mine ? null : () => _reshare(reel),
      ),
    );
  }

  void _audience(Content reel) => showContentAudienceSheet(
    context,
    contentId: reel.id,
    onOpenProfile: (userId) =>
        unawaited(context.push(RoutePaths.userProfileOf(userId))),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentFeedProvider(SocialFeedKind.reels));
    final notifier = ref.read(
      contentFeedProvider(SocialFeedKind.reels).notifier,
    );
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    // The first reel is on screen before any page change fires.
    if (!_firstViewSent && state.items.isNotEmpty) {
      _firstViewSent = true;
      final first = state.items.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markViewed(first);
      });
    }

    return Scaffold(
      // Reels are watched on a dark ground whatever the theme: the clip is the
      // light source, and a white surround competes with it.
      backgroundColor: DsColors.mediaGround,
      extendBodyBehindAppBar: true,
      appBar: ReemAppBar(
        title: context.l10n.reelsTitle,
        transparent: true,
        showBack: true,
      ),
      body: switch (state) {
        _ when state.isLoading && state.items.isEmpty => const Center(
          child: DsLoadingIndicator(),
        ),
        _ when state.hasError && state.items.isEmpty => DsErrorState(
          message: state.error,
          onRetry: notifier.load,
        ),
        _ when state.items.isEmpty => DsEmptyState(
          icon: Icons.movie_creation_outlined,
          title: context.l10n.reelsEmptyTitle,
          message: context.l10n.reelsEmptyBody,
        ),
        _ => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: state.items.length,
            onPageChanged: (index) {
              _markViewed(state.items[index]);
              // Two from the end, so the next page is there before she
              // reaches it — a reel that has to buffer while she waits is the
              // one she scrolls past.
              if (index >= state.items.length - 2) notifier.loadMore();
            },
            itemBuilder: (context, index) {
              final reel = state.items[index];
              final mine = reel.author.id == me;
              return _Reel(
                key: ValueKey(reel.id),
                content: reel,
                isMine: mine,
                onLike: () => _like(reel),
                onDoubleTap: () => _like(reel, onlyAdd: true),
                onSave: () => _save(reel),
                onComment: () => _comment(reel),
                onShare: () => _share(reel),
                onReshare: mine ? null : () => _reshare(reel),
                onMore: () => _more(reel, me),
                onAudience: mine ? () => _audience(reel) : null,
                onWatched: (watched) => ref
                    .read(socialRepositoryProvider)
                    .recordEvent(
                      reel.id,
                      'WATCH_TIME',
                      watchTimeMs: watched.inMilliseconds,
                    ),
              );
            },
          ),
        ),
      },
    );
  }
}

class _Reel extends StatefulWidget {
  const _Reel({
    super.key,
    required this.content,
    required this.isMine,
    required this.onLike,
    required this.onDoubleTap,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    required this.onMore,
    required this.onWatched,
    this.onReshare,
    this.onAudience,
  });

  final Content content;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onDoubleTap;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback? onReshare;

  /// «شوهدت من قبل» — only on her own reel.
  final VoidCallback? onAudience;
  final void Function(Duration) onWatched;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: DsMotion.slow,
  );
  bool _captionOpen = false;

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _doubleTap() {
    unawaited(_burst.forward(from: 0));
    widget.onDoubleTap();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final video = content.video;
    final tag = content.primaryTag;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTap: _doubleTap,
          child: video != null
              ? DsVideoPlayer(
                  url: video.url,
                  thumbnailUrl: video.thumbnailUrl,
                  blurHash: video.blurHash,
                  fit: BoxFit.contain,
                  mutePlacement: DsVideoMutePlacement.topEnd,
                  onWatched: widget.onWatched,
                )
              : const DsMediaFallback(),
        ),

        // The heart that answers a double tap.
        IgnorePointer(
          child: Center(
            child: AnimatedBuilder(
              animation: _burst,
              builder: (context, _) {
                final t = _burst.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                final scale = Curves.elasticOut.transform(
                  (t * 2).clamp(0.0, 1.0),
                );
                return Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.6 + scale * 0.6,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: DsSizes.iconXl * 2,
                      color: context.dsColors.favorite,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // A wash under the copy, so white text stays legible over a pale clip.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 320,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: context.imageScrim),
            ),
          ),
        ),

        Positioned(
          left: DsSpacing.md,
          right: 84,
          bottom: DsSpacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () =>
                    context.push(RoutePaths.userProfileOf(content.author.id)),
                child: Row(
                  children: [
                    DsAvatar(
                      imageUrl: content.author.imageUrl,
                      name: content.author.name,
                      size: DsSizes.avatarXs,
                    ),
                    DsGaps.hSm,
                    Flexible(
                      child: Text(
                        content.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.cardTitle.tint(DsColors.onMedia),
                      ),
                    ),
                  ],
                ),
              ),
              if (content.caption.isNotEmpty) ...[
                DsGaps.vSm,
                // A long caption opens on a tap rather than being cut off for
                // good — the size guide or the delivery note is usually the
                // part past the third line.
                GestureDetector(
                  onTap: () => setState(() => _captionOpen = !_captionOpen),
                  child: Text(
                    content.caption,
                    maxLines: _captionOpen ? 12 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.tint(DsColors.onMedia),
                  ),
                ),
              ],
              if (tag != null) ...[
                DsGaps.vMd,
                DsShopPlate(
                  product: tag.product,
                  onTap: () =>
                      context.push(RoutePaths.productDetailsOf(tag.product.id)),
                ),
              ],
            ],
          ),
        ),

        Positioned(
          right: DsSpacing.md,
          bottom: DsSpacing.xl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailAction(
                icon: content.viewer.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: content.counts.likes,
                tooltip: context.l10n.a11yLike,
                active: content.viewer.isLiked,
                onTap: widget.onLike,
              ),
              _RailAction(
                icon: Icons.mode_comment_outlined,
                label: content.counts.comments,
                tooltip: context.l10n.comments,
                onTap: widget.onComment,
              ),
              if (widget.onReshare case final reshare?)
                _RailAction(
                  icon: content.viewer.isReshared
                      ? Icons.bookmark_added_rounded
                      : Icons.add_to_photos_outlined,
                  label: content.counts.shares,
                  tooltip: context.l10n.contentAddToMyPage,
                  active: content.viewer.isReshared,
                  onTap: reshare,
                ),
              _RailAction(
                icon: Icons.ios_share_rounded,
                tooltip: context.l10n.contentShare,
                onTap: widget.onShare,
              ),
              _RailAction(
                icon: content.viewer.isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: context.l10n.a11ySave,
                active: content.viewer.isSaved,
                onTap: widget.onSave,
              ),
              if (widget.onAudience case final audience?)
                _RailAction(
                  icon: Icons.visibility_outlined,
                  label: content.counts.views,
                  tooltip: context.l10n.audienceTitle,
                  onTap: audience,
                ),
              _RailAction(
                icon: Icons.more_horiz_rounded,
                tooltip: context.l10n.a11yMore,
                onTap: widget.onMore,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int? label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final count = label;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: tooltip,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                icon,
                size: DsSizes.iconLg,
                color: active ? context.dsColors.favorite : DsColors.onMedia,
              ),
            ),
          ),
          if (count != null && count > 0)
            Text('$count', style: context.dsText.micro.tint(DsColors.onMedia)),
        ],
      ),
    );
  }
}
