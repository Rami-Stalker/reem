import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_tier.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// One piece of content in a feed.
///
/// The card every social surface renders through — the discover feed, the
/// following feed, a woman's page, the rail on a product. One card because
/// they are one object: a post, a reel and a story differ by format, and a
/// second card per format would be three places to fix a broken share button.
///
/// Two things it must always get right:
///
/// **The boutique keeps its credit.** A reshare on a woman's page is drawn
/// as the boutique's own post — [content.author] heads it and tapping the
/// author goes to the boutique. There is no «أضافته … إلى صفحتها» band above
/// it: the page it sits on already says whose picks these are, and the band
/// repeated it over every card.
///
/// **The way to buy is always one tap.** The shop plate sits over the foot of
/// the image, not below the fold, because the whole premise is that discovery
/// and purchase are the same gesture.
/// The label and icon for why a ranked feed showed a piece, or null when it
/// needs no saying: someone she follows, or a guest's general feed.
(String, IconData)? rankReasonChip(
  AppLocalizations l10n,
  ContentRankReason? reason,
) => switch (reason) {
  ContentRankReason.forYou => (
    l10n.feedReasonForYou,
    Icons.auto_awesome_outlined,
  ),
  ContentRankReason.trending => (
    l10n.feedReasonTrending,
    Icons.local_fire_department_outlined,
  ),
  ContentRankReason.newVoice => (
    l10n.feedReasonNewVoice,
    Icons.waving_hand_outlined,
  ),
  ContentRankReason.following || ContentRankReason.popular || null => null,
};

class ContentCard extends StatefulWidget {
  const ContentCard({
    super.key,
    required this.content,
    required this.onOpenAuthor,
    required this.onOpenProduct,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    this.onReshare,
    this.onMore,
    this.featured = false,
  });

  final Content content;

  final void Function(String userId) onOpenAuthor;
  final void Function(String productId) onOpenProduct;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;

  /// «أضيفي إلى صفحتي». Null on her own content — she cannot reshare herself.
  final VoidCallback? onReshare;
  final VoidCallback? onMore;

  /// The first card in an editorial run gets the wider ornament ring.
  final bool featured;

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  /// Double-tap only ever loves; it never takes a like back.
  void _doubleTap() {
    _burst.forward(from: 0);
    if (!widget.content.viewer.isLiked) widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final l10n = context.l10n;
    final tag = content.primaryTag;
    final video = content.video;
    final author = content.author;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.gutter),
      child: DsImmersivePost(
        featured: widget.featured,
        authorName: author.name,
        authorImageUrl: author.imageUrl,
        authorVerified: author.isVerified,
        // A shopper's look and a boutique's marketing are different things,
        // and the difference is what makes the first trustworthy. It is
        // stated, not left to be inferred from the photograph.
        subtitle:
            '${content.authorKind.isCustomer ? l10n.contentFromShopper : l10n.contentFromBoutique}'
            ' · ${dsShortTimeAgo(context, content.publishedAt ?? content.createdAt)}',
        onAuthor: () => widget.onOpenAuthor(author.id),
        onMore: widget.onMore,
        badges: [
          if (content.isUnderReview)
            DsBadge(label: l10n.contentUnderReview, tone: DsBadgeTone.warning),
          // A paid post says so, plainly, before anything else about it.
          if (content.sponsorship case final sponsored?) ...[
            DsBadge(
              label: l10n.searchSponsored,
              tone: DsBadgeTone.neutral,
              icon: Icons.campaign_outlined,
            ),
            if (storeTierJewel(sponsored.storeTier) case final jewel?)
              DsTierBadge(
                tier: jewel,
                label: storeTierLabel(l10n, sponsored.storeTier),
              ),
          ]
          // Why the feed brought her something she does not follow. Someone
          // she follows needs no explanation, and a guest's feed has none.
          else if (rankReasonChip(l10n, content.rankReason)
              case (final label, final icon))
            DsBadge(label: label, tone: DsBadgeTone.info, icon: icon),
        ],
        // A reel plays in the feed, muted, and only while it is on screen.
        mediaOverride: video == null
            ? null
            : DsVideoPlayer(
                url: video.url,
                thumbnailUrl: video.thumbnailUrl,
                blurHash: video.blurHash,
                showControls: false,
              ),
        media: content.media,
        product: tag?.product,
        onOpenProduct: tag == null
            ? null
            : () => widget.onOpenProduct(tag.product.id),
        caption: content.caption,
        liked: content.viewer.isLiked,
        saved: content.viewer.isSaved,
        picked: content.viewer.isReshared,
        likes: content.counts.likes,
        comments: content.counts.comments,
        shares: content.counts.shares,
        burst: _burst,
        onLike: widget.onLike,
        onDoubleTap: _doubleTap,
        onComment: widget.onComment,
        onShare: widget.onShare,
        onSave: widget.onSave,
        onPick: widget.onReshare,
      ),
    );
  }
}

/// A story bubble in the tray.
class StoryBubble extends StatelessWidget {
  const StoryBubble({
    super.key,
    required this.author,
    required this.allSeen,
    required this.onTap,
  });

  final User author;
  final bool allSeen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DsStoryCard(
      label: author.name,
      imageUrl: author.imageUrl,
      seen: allSeen,
      isVerified: author.isVerified,
      onTap: onTap,
    );
  }
}

/// The photograph itself, for a grid on somebody's page.
class ContentGridTile extends StatelessWidget {
  const ContentGridTile({
    super.key,
    required this.content,
    required this.onTap,
  });

  final Content content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final cover = content.cover;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null)
            LayoutBuilder(
              builder: (context, constraints) => CachedNetworkImage(
                imageUrl: MediaVariants.thumb(cover.displayUrl),
                memCacheWidth: MediaDecode.widthFrom(context, constraints),
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                errorWidget: (_, _, _) => const DsMediaFallback(),
              ),
            )
          else
            const DsMediaFallback(),
          if (content.format.isVideo)
            Positioned(
              top: DsSpacing.xs,
              right: DsSpacing.xs,
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: DsSizes.iconSm,
                color: DsColors.onMedia,
              ),
            ),
          if (content.hasProducts)
            Positioned(
              left: DsSpacing.xs,
              bottom: DsSpacing.xs,
              child: Icon(
                Icons.local_mall_rounded,
                size: DsSizes.iconXs,
                color: DsColors.onMedia,
              ),
            ),
        ],
      ),
    );
  }
}
