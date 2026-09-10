import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/social/domain/entities/content.dart';

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

class _ContentCardState extends State<ContentCard> {
  int _mediaIndex = 0;

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.gutter),
      child: DsGradientBorder(
        radius: DsRadius.card,
        width: widget.featured ? 2 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DsRadius.card),
          child: ColoredBox(
            color: c.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.resharedBy != null)
                  _ReshareBanner(
                    resharer: widget.resharedBy!,
                    note: widget.reshareNote,
                    onTap: () => widget.onOpenAuthor(widget.resharedBy!.id),
                  ),
                _Header(
                  content: content,
                  onTap: () => widget.onOpenAuthor(content.author.id),
                  onMore: widget.onMore,
                ),
                if (content.hasMedia)
                  _Media(
                    content: content,
                    index: _mediaIndex,
                    onIndexChanged: (index) =>
                        setState(() => _mediaIndex = index),
                    onOpenProduct: widget.onOpenProduct,
                  ),
                if (content.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpacing.md,
                      DsSpacing.sm,
                      DsSpacing.md,
                      0,
                    ),
                    child: Text(
                      content.caption,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body,
                    ),
                  ),
                _Actions(
                  content: content,
                  onLike: widget.onLike,
                  onSave: widget.onSave,
                  onComment: widget.onComment,
                  onShare: widget.onShare,
                  onReshare: widget.onReshare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «أضافتها إلى صفحتها» — who put this here, above whose post it is.
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
    final c = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: c.primaryContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.autorenew_rounded,
                  size: DsSizes.iconXs,
                  color: c.onPrimaryContainer,
                ),
                DsGaps.hXs,
                Flexible(
                  child: Text(
                    context.l10n.contentResharedBy(resharer.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(c.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            if (note != null && note!.isNotEmpty) ...[
              DsGaps.vXxs,
              Text(
                note!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.body.tint(c.onPrimaryContainer),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.content, required this.onTap, this.onMore});

  final Content content;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final author = content.author;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.sm,
        DsSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: DsAvatar(
              imageUrl: author.imageUrl,
              name: author.name,
              size: DsSizes.avatarSm,
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.cardTitle,
                        ),
                      ),
                      if (author.isVerified) ...[
                        DsGaps.hXxs,
                        Icon(
                          Icons.verified_rounded,
                          size: DsSizes.iconXs,
                          color: c.primary,
                        ),
                      ],
                    ],
                  ),
                  // A shopper's look and a boutique's marketing are different
                  // things, and the difference is what makes the first
                  // trustworthy. It is stated, not left to be inferred from
                  // the photograph.
                  Text(
                    content.authorKind.isCustomer
                        ? context.l10n.contentFromShopper
                        : context.l10n.contentFromBoutique,
                    style: context.dsText.micro.tint(c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (content.isUnderReview)
            DsBadge(
              label: context.l10n.contentUnderReview,
              tone: DsBadgeTone.warning,
            ),
          if (onMore != null)
            DsIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: context.l10n.postMore,
              onPressed: onMore,
            ),
        ],
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({
    required this.content,
    required this.index,
    required this.onIndexChanged,
    required this.onOpenProduct,
  });

  final Content content;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final void Function(String productId) onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final media = content.media;
    final tag = content.primaryTag;
    final video = content.video;

    return AspectRatio(
      // 4:5, the portrait ratio the shooting guide asks boutiques for.
      aspectRatio: DsSizes.aspectPortrait,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video != null)
            // A reel plays in the feed, muted, and only while it is on screen.
            DsVideoPlayer(
              url: video.url,
              thumbnailUrl: video.thumbnailUrl,
              blurHash: video.blurHash,
              showControls: false,
            )
          else
            PageView.builder(
              itemCount: media.length,
              onPageChanged: onIndexChanged,
              itemBuilder: (_, i) => DsMediaFrame(item: media[i]),
            ),
          if (media.length > 1)
            Positioned(
              top: DsSpacing.sm,
              right: DsSpacing.sm,
              child: DsCounterPill(index: index, count: media.length),
            ),
          if (tag != null)
            Positioned(
              left: DsSpacing.md,
              right: DsSpacing.md,
              bottom: DsSpacing.md,
              child: DsShopPlate(
                product: tag.product,
                onTap: () => onOpenProduct(tag.product.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.content,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    this.onReshare,
  });

  final Content content;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onReshare;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final viewer = content.viewer;
    final counts = content.counts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.sm,
        DsSpacing.xs,
        DsSpacing.sm,
        DsSpacing.sm,
      ),
      child: Row(
        children: [
          _Action(
            icon: viewer.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: viewer.isLiked ? c.favorite : null,
            label: counts.likes,
            tooltip: context.l10n.a11yLike,
            onTap: onLike,
          ),
          _Action(
            icon: Icons.mode_comment_outlined,
            label: counts.comments,
            tooltip: context.l10n.comments,
            onTap: onComment,
          ),
          _Action(
            icon: Icons.ios_share_rounded,
            label: counts.shares,
            tooltip: context.l10n.contentShare,
            onTap: onShare,
          ),
          if (onReshare != null)
            _Action(
              // The gesture the whole feature turns on, so it is a labelled
              // control rather than a glyph in an overflow menu.
              icon: viewer.isReshared
                  ? Icons.bookmark_added_rounded
                  : Icons.add_to_photos_outlined,
              color: viewer.isReshared ? c.primary : null,
              tooltip: context.l10n.contentAddToMyPage,
              onTap: onReshare!,
            ),
          const Spacer(),
          DsIconButton(
            icon: viewer.isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: viewer.isSaved ? c.primary : null,
            tooltip: context.l10n.a11ySave,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final count = label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIconButton(
          icon: icon,
          tooltip: tooltip,
          color: color,
          onPressed: onTap,
        ),
        if (count != null && count > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: DsSpacing.xs),
            child: Text('$count', style: context.dsText.caption),
          ),
      ],
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
