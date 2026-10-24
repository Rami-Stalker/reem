import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/social/domain/entities/content.dart';

/// One piece of content in a feed.
///
/// The card every social surface renders through — the discover feed, the
/// following feed, a woman's page, the rail on a product. One card because
/// they are one object: a post, a reel and a story differ by format, and a
/// second card per format would be three places to fix a broken share button.
///
/// Two things it must always get right:
///
/// **The boutique keeps its credit.** When this is a reshare, [resharedBy] is
/// the woman who added it and [content.author] is still the boutique — the
/// attribution line says both, in that order, and tapping the author goes to
/// the boutique. A card that let the resharer read as the source would defeat
/// the entire feature.
///
/// **The way to buy is always one tap.** The shop plate sits over the foot of
/// the image, not below the fold, because the whole premise is that discovery
/// and purchase are the same gesture.
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
    this.resharedBy,
    this.reshareNote,
    this.featured = false,
  });

  final Content content;

  /// Set when this is somebody else's post on a woman's page.
  final User? resharedBy;
  final String? reshareNote;

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
        banner: widget.resharedBy == null
            ? null
            : _ReshareBanner(
                resharer: widget.resharedBy!,
                note: widget.reshareNote,
                onTap: () => widget.onOpenAuthor(widget.resharedBy!.id),
              ),
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

/// «أضافتها إلى صفحتها» — who put this here, above whose post it is.
///
/// Her face and her name on a soft rose capsule, and what she said about it
/// as a quote beneath — set apart from the card so it can never be read as
/// the boutique's own words.
class _ReshareBanner extends StatelessWidget {
  const _ReshareBanner({
    required this.resharer,
    required this.onTap,
    this.note,
  });

  final User resharer;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final text = context.dsText;
    final note = this.note?.trim();

    return DsScaleAnimations.tapScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.xxs,
              DsSpacing.xxs,
              DsSpacing.sm,
              DsSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: p.primarySoft.withValues(alpha: 0.7),
              borderRadius: DsRadius.borderPill,
              border: Border.all(color: p.primary.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DsAvatar(
                  imageUrl: resharer.imageUrl,
                  name: resharer.name,
                  size: DsSizes.avatarXs,
                ),
                DsGaps.hXs,
                Flexible(
                  child: Text(
                    context.l10n.contentResharedBy(resharer.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.captionStrong.tint(p.ink),
                  ),
                ),
                DsGaps.hXs,
                Icon(
                  Icons.autorenew_rounded,
                  size: DsSizes.iconXs,
                  color: p.primary,
                ),
              ],
            ),
          ),
          if (note != null && note.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: DsSpacing.md,
                top: DsSpacing.xs,
              ),
              child: Container(
                padding: const EdgeInsetsDirectional.only(start: DsSpacing.sm),
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: p.gold,
                      width: DsSpacing.xxxs,
                    ),
                  ),
                ),
                child: Text(
                  '«$note»',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.body.displayFamily.tint(p.ink),
                ),
              ),
            ),
        ],
      ),
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
