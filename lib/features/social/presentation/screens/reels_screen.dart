import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/widgets/content_comments_sheet.dart';
import 'package:reem/features/social/presentation/widgets/reshare_sheet.dart';

/// Reels: one clip at a time, full bleed, with the way to buy on the glass.
///
/// The commerce case is what makes this different from a video feed. A reel
/// that cannot be bought from is entertainment; the shop plate sits over the
/// bottom third, where her thumb already is, and the tap goes straight to the
/// boutique's product page.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentFeedProvider(SocialFeedKind.reels));
    final notifier = ref.read(
      contentFeedProvider(SocialFeedKind.reels).notifier,
    );
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));

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
        _ => PageView.builder(
          controller: _pages,
          scrollDirection: Axis.vertical,
          itemCount: state.items.length,
          onPageChanged: (index) {
            // Two from the end, so the next page is there before she reaches
            // it — a reel that has to buffer while she waits is the one she
            // scrolls past.
            if (index >= state.items.length - 2) notifier.loadMore();
          },
          itemBuilder: (context, index) {
            final reel = state.items[index];
            return _Reel(
              content: reel,
              canReshare: reel.author.id != me,
              onLike: () => notifier.toggleLike(reel.id),
              onSave: () => notifier.toggleSave(reel.id),
              onComment: () async {
                final delta = await showContentComments(
                  context,
                  contentId: reel.id,
                );
                notifier.adjustComments(reel.id, delta);
              },
              onShare: () async {
                final shared = await ShareService.post(
                  context: context,
                  postId: reel.id,
                  caption: reel.caption,
                  authorName: reel.author.name,
                  imageUrl: reel.shareImageUrl,
                );
                if (shared) await notifier.recordShare(reel.id);
              },
              onReshare: () async {
                if (reel.viewer.isReshared) {
                  await notifier.toggleReshare(reel.id);
                  return;
                }
                final note = await showReshareSheet(context, content: reel);
                if (note == null) return;
                await notifier.toggleReshare(
                  reel.id,
                  note: note.isEmpty ? null : note,
                );
              },
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
      },
    );
  }
}

class _Reel extends StatelessWidget {
  const _Reel({
    required this.content,
    required this.canReshare,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    required this.onReshare,
    required this.onWatched,
  });

  final Content content;
  final bool canReshare;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReshare;
  final void Function(Duration) onWatched;

  @override
  Widget build(BuildContext context) {
    final video = content.video;
    final tag = content.primaryTag;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (video != null)
          DsVideoPlayer(
            url: video.url,
            thumbnailUrl: video.thumbnailUrl,
            blurHash: video.blurHash,
            fit: BoxFit.contain,
            onWatched: onWatched,
          )
        else
          const DsMediaFallback(),

        // A wash under the copy, so white text stays legible over a pale clip.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 320,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: context.imageScrim),
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
                Text(
                  content.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body.tint(DsColors.onMedia),
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
                onTap: onLike,
              ),
              _RailAction(
                icon: Icons.mode_comment_outlined,
                label: content.counts.comments,
                tooltip: context.l10n.comments,
                onTap: onComment,
              ),
              if (canReshare)
                _RailAction(
                  icon: content.viewer.isReshared
                      ? Icons.bookmark_added_rounded
                      : Icons.add_to_photos_outlined,
                  label: content.counts.shares,
                  tooltip: context.l10n.contentAddToMyPage,
                  active: content.viewer.isReshared,
                  onTap: onReshare,
                ),
              _RailAction(
                icon: Icons.ios_share_rounded,
                tooltip: context.l10n.contentShare,
                onTap: onShare,
              ),
              _RailAction(
                icon: content.viewer.isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: context.l10n.a11ySave,
                active: content.viewer.isSaved,
                onTap: onSave,
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
              child: Icon(
                icon,
                size: DsSizes.iconLg,
                color: active
                    ? context.dsColors.favorite
                    : DsColors.onMedia,
              ),
            ),
          ),
          if (count != null && count > 0)
            Text(
              '$count',
              style: context.dsText.micro.tint(DsColors.onMedia),
            ),
        ],
      ),
    );
  }
}
