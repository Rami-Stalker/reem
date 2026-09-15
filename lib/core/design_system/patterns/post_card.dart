import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';

/// The pieces of Reem's post card, shared by everything that is read as a post.
///
/// These lived privately inside the home feed's `ReemPostCard`. A department
/// page then drew its products "as posts" with a second, thinner card — no
/// heart, no comments, no share, no bookmark — and the client, rightly, asked
/// why the posts under «مكياج» were not the posts under «وصل حديثاً». Two cards
/// for one shape is how that happens, so the shape now lives here once: a post
/// from a boutique and a product told as a post are assembled from the same
/// frame, header, gallery, action bar and caption, and can only differ in what
/// they are fed.
///
/// Everything is presentational. Counts, flags and callbacks come in; nothing
/// here knows what a like is stored as.

// ---------------------------------------------------------------------------
// Frame
// ---------------------------------------------------------------------------

/// The rose-to-champagne thread around a post, and the light under it.
class DsPostFrame extends StatelessWidget {
  const DsPostFrame({super.key, required this.child, this.featured = false});

  final Widget child;

  /// The first card of a run is given a wider ring and a warmer glow, so the
  /// eye lands there first.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    // A thread, not a frame: brand-coloured but held well under full opacity,
    // so a whole column of these still reads calm.
    final ring = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        c.primary.withValues(alpha: featured ? 0.62 : 0.38),
        c.secondary.withValues(alpha: featured ? 0.34 : 0.18),
        c.accent.withValues(alpha: featured ? 0.62 : 0.38),
      ],
    );

    return DsGradientBorder(
      radius: 34,
      width: featured ? 1.6 : 1.1,
      gradient: ring,
      backgroundColor: c.card,
      boxShadow: [
        // A rose bloom under the card, then a neutral lift. Two shadows read
        // as light falling on silk; one flat drop reads as a box.
        BoxShadow(
          color: c.primary.withValues(alpha: featured ? 0.18 : 0.10),
          blurRadius: featured ? 40 : 30,
          offset: const Offset(0, 16),
        ),
        BoxShadow(color: c.shadow, blurRadius: 18, offset: const Offset(0, 6)),
      ],
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// The masthead: who is speaking, what about, and the post's menu.
class DsPostHeader extends StatelessWidget {
  const DsPostHeader({
    super.key,
    required this.name,
    required this.subtitle,
    this.imageUrl,
    this.isVerified = false,
    this.onAuthor,
    this.onMore,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool isVerified;
  final VoidCallback? onAuthor;

  /// The «…» menu. Always offered when given — a glyph that does nothing on
  /// tap reads as a broken control, which is exactly what the client reported.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Padding(
      // Directional: the tighter end inset belongs beside the "more" button,
      // which sits on the left in Arabic.
      padding: const EdgeInsetsDirectional.fromSTEB(
        DsSpacing.sm,
        DsSpacing.sm,
        DsSpacing.xs,
        DsSpacing.sm,
      ),
      child: Row(
        children: [
          DsAvatar(
            imageUrl: imageUrl,
            name: name,
            size: 46,
            hasRing: true,
            onTap: onAuthor,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: onAuthor,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        // Set in the display serif: the name is the masthead
                        // of its post, and Cairo picks up the Arabic through
                        // the family fallback.
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.tileTitle.displayFamily.bold
                              .tint(c.onSurface)
                              .copyWith(height: 1.25),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: DsSpacing.xxs),
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: c.secondary,
                        ),
                      ],
                    ],
                  ),
                  DsGaps.vXxxs,
                  Row(
                    children: [
                      DsSparkle(size: 8, color: c.accent, opacity: 0.9),
                      const SizedBox(width: DsSpacing.xxs),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (onMore != null)
            DsIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: context.l10n.postOptions,
              variant: DsIconButtonVariant.ghost,
              size: 40,
              onPressed: onMore,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gallery
// ---------------------------------------------------------------------------

/// The 4:5 plate: a swipeable gallery, its badges, the frosted shop plate and
/// the double-tap burst.
class DsPostGallery extends StatefulWidget {
  const DsPostGallery({
    super.key,
    required this.media,
    required this.burst,
    required this.index,
    required this.onIndex,
    required this.onTap,
    required this.onDoubleTap,
    this.product,
    this.isFresh = false,
    this.onAddToBag,
  });

  final List<MediaItem> media;
  final Product? product;
  final int index;

  /// Posted within the last few days — earns the champagne "new" ribbon.
  final bool isFresh;
  final VoidCallback? onAddToBag;
  final AnimationController burst;
  final ValueChanged<int> onIndex;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  State<DsPostGallery> createState() => _DsPostGalleryState();
}

class _DsPostGalleryState extends State<DsPostGallery> {
  final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final product = widget.product;
    final count = math.max(widget.media.length, 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DsRadius.xxl),
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.media.isEmpty)
                  const DsMediaFallback()
                else
                  PageView.builder(
                    controller: _pages,
                    physics: count > 1
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: widget.onIndex,
                    itemCount: count,
                    itemBuilder: (_, i) => DsMediaFrame(item: widget.media[i]),
                  ),

                // Scrims: a whisper at the top so the badges read, a deeper one
                // at the foot so the frosted plate has something to sit on.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: context.imageScrimTop),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: context.imageScrim),
                  ),
                ),

                PositionedDirectional(
                  top: DsSpacing.sm,
                  start: DsSpacing.sm,
                  child: Row(
                    children: [
                      if (product != null && product.hasDiscount) ...[
                        DsDiscountBadge(percentOff: product.discountPercent),
                        const SizedBox(width: DsSpacing.xxs),
                      ],
                      if (widget.isFresh) const _FreshRibbon(),
                    ],
                  ),
                ),

                PositionedDirectional(
                  top: DsSpacing.sm,
                  end: DsSpacing.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (count > 1)
                        DsCounterPill(index: widget.index, count: count),
                      if (product != null && product.rating > 0) ...[
                        if (count > 1) const SizedBox(height: DsSpacing.xxs),
                        DsRatingChip(
                          rating: product.rating,
                          reviews: product.reviewsCount,
                        ),
                      ],
                    ],
                  ),
                ),

                if (product != null)
                  PositionedDirectional(
                    start: DsSpacing.sm,
                    end: DsSpacing.sm,
                    bottom: DsSpacing.sm,
                    child: DsShopPlate(
                      product: product,
                      onTap: widget.onTap,
                      onAddToBag: widget.onAddToBag,
                    ),
                  ),

                IgnorePointer(
                  child: Center(
                    child: DsLoveBurst(
                      controller: widget.burst,
                      color: c.favorite,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A painted canvas for a post that carries only words.
///
/// A boutique's note, a thank-you, an announcement — content with no gallery
/// and nothing tagged. The caption is set large in the display serif on a
/// blush wash. It still takes a double-tap, so loving a note feels no
/// different from loving a dress.
class DsPostQuote extends StatelessWidget {
  const DsPostQuote({
    super.key,
    required this.caption,
    required this.onDoubleTap,
    required this.burst,
  });

  final String caption;
  final VoidCallback onDoubleTap;
  final AnimationController burst;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 190),
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xl,
            vertical: DsSpacing.xxl,
          ),
          decoration: BoxDecoration(
            gradient: context.softGradient,
            borderRadius: BorderRadius.circular(DsRadius.xxl),
            border: Border.all(color: c.primary.withValues(alpha: 0.14)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              PositionedDirectional(
                top: 0,
                start: 0,
                child: DsSparkle(size: 14, color: c.accent, opacity: 0.75),
              ),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: DsSparkle(size: 11, color: c.primary, opacity: 0.6),
              ),
              Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.sectionTitle.displayFamily
                    .tint(c.onSurface)
                    .copyWith(height: 1.5),
              ),
              IgnorePointer(
                child: DsLoveBurst(controller: burst, color: c.favorite),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A champagne "just in" ribbon for a post only a few days old.
class _FreshRibbon extends StatelessWidget {
  const _FreshRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        gradient: context.champagneGradient,
        borderRadius: DsRadius.borderPill,
        boxShadow: context.shadowXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DsSparkle(size: 9, color: DsColors.onChampagne),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            context.l10n.justIn.toUpperCase(),
            // Deep gold ink: the ribbon's ground is the champagne gradient,
            // which is fixed in both themes, so the text must be too.
            style: context.dsText.badge.tint(DsColors.onChampagne),
          ),
        ],
      ),
    );
  }
}

/// Gallery position: soft dots with the active one stretched into a rose
/// capsule — quicker to read at a glance than a bare "2/5".
class DsPostDots extends StatelessWidget {
  const DsPostDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: DsMotion.fast,
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              gradient: i == index ? context.primaryGradient : null,
              color: i == index ? null : c.border,
              borderRadius: DsRadius.borderPill,
            ),
          ),
      ],
    );
  }
}

/// The double-tap reward: one big heart plus a scatter of petals and sparkles.
class DsLoveBurst extends StatelessWidget {
  const DsLoveBurst({super.key, required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  static const int _petals = 9;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        if (v == 0) return const SizedBox.shrink();

        final pop = Curves.easeOutBack.transform((v / 0.42).clamp(0.0, 1.0));
        final fade =
            1 - Curves.easeIn.transform(((v - 0.5) / 0.5).clamp(0.0, 1.0));
        final spread = Curves.easeOutCubic.transform(v);

        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < _petals; i++) _petal(i, spread, fade),
            Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: 0.45 + pop * 0.7,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 104,
                  color: DsColors.onMedia.withValues(alpha: 0.94),
                  shadows: [
                    Shadow(
                      blurRadius: 30,
                      color: color.withValues(alpha: 0.55),
                    ),
                    const Shadow(blurRadius: 18, color: DsColors.mediaScrim),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _petal(int i, double spread, double fade) {
    final angle = (i / _petals) * math.pi * 2 + 0.32;
    final distance = 34 + 82 * spread;
    final size = 9.0 + (i.isEven ? 7 : 3);
    return Transform.translate(
      offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
      child: Opacity(
        opacity: fade * 0.9,
        child: Transform.rotate(
          angle: angle,
          child: Icon(
            i.isEven ? Icons.favorite_rounded : Icons.auto_awesome_rounded,
            size: size,
            color: i.isEven ? color : DsColors.onMedia,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// Heart, comments, share, «أضيفي إلى صفحتي» — and the bookmark at the end.
class DsPostActionBar extends StatelessWidget {
  const DsPostActionBar({
    super.key,
    required this.liked,
    required this.saved,
    required this.commentsCount,
    required this.sharesCount,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    this.picked = false,
    this.onPick,
  });

  final bool liked;
  final bool saved;
  final int commentsCount;
  final int sharesCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  /// Whether she already added it to her page.
  final bool picked;

  /// «أضيفي إلى صفحتي». Null hides it — her own post cannot go on her page
  /// twice.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.xxs,
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: liked ? c.favorite : c.onSurface,
            active: liked,
            label: l10n.a11yLike,
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.mode_comment_outlined,
            color: c.onSurface,
            label: l10n.comments,
            count: commentsCount > 0 ? formatCount(commentsCount) : null,
            onTap: onComment,
          ),
          _ActionButton(
            icon: Icons.send_rounded,
            color: c.onSurface,
            label: l10n.contentShare,
            count: sharesCount > 0 ? formatCount(sharesCount) : null,
            onTap: onShare,
          ),
          if (onPick != null)
            _ActionButton(
              icon: picked
                  ? Icons.library_add_check_rounded
                  : Icons.add_to_photos_outlined,
              color: picked ? c.primary : c.onSurface,
              active: picked,
              label: l10n.contentAddToMyPage,
              onTap: onPick!,
            ),
          const Spacer(),
          _ActionButton(
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: saved ? c.secondary : c.onSurface,
            active: saved,
            label: l10n.a11ySave,
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.count,
    this.active = false,
  });

  final IconData icon;
  final Color color;

  /// What a screen reader says; the glyph alone says nothing.
  final String label;
  final VoidCallback onTap;
  final String? count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.16 : 1,
                duration: DsMotion.fast,
                curve: DsMotion.softSpring,
                child: Icon(icon, size: DsConstraints.iconMd, color: color),
              ),
              if (count != null) ...[
                const SizedBox(width: DsSpacing.xxs),
                Text(
                  count!,
                  style: context.dsText.label.copyWith(
                    color: context.dsColors.onSurface,
                    fontWeight: DsTypography.medium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Caption
// ---------------------------------------------------------------------------

/// Likes line, caption with rose hashtags, and "view all N comments".
class DsPostCaption extends StatelessWidget {
  const DsPostCaption({
    super.key,
    required this.authorName,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.expanded,
    required this.onExpand,
    required this.onComments,
    this.showCaption = true,
  });

  final String authorName;
  final String caption;
  final int likes;

  /// The card's live tally — it moves the moment she comments.
  final int comments;
  final bool showCaption;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.sm,
        DsSpacing.xxs,
        DsSpacing.sm,
        DsSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (likes > 0)
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 13, color: c.favorite),
                const SizedBox(width: DsSpacing.xxs),
                Text(
                  l10n.postLikesCount(formatCount(likes)),
                  style: context.dsText.labelLarge.copyWith(
                    fontWeight: DsTypography.semiBold,
                  ),
                ),
              ],
            ),
          if (showCaption && caption.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xxs),
            GestureDetector(
              onTap: expanded ? null : onExpand,
              child: RichText(
                maxLines: expanded ? null : 2,
                overflow: expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                text: TextSpan(
                  style: context.dsText.body.copyWith(height: 1.45),
                  children: [
                    TextSpan(
                      text: '$authorName  ',
                      style: context.dsText.body.copyWith(
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                    ..._captionSpans(caption, c.primary),
                    if (!expanded)
                      TextSpan(
                        text: '  ${l10n.postMore}',
                        style: context.dsText.body.copyWith(
                          color: c.onSurfaceVariant,
                          fontWeight: DsTypography.semiBold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: DsSpacing.xs),
          GestureDetector(
            onTap: onComments,
            child: Text(
              comments > 0
                  ? l10n.postViewComments(formatCount(comments))
                  : l10n.beTheFirstToComment,
              style: context.dsText.cardSubtitle.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Splits the caption so hashtags and mentions come through in brand rose —
  /// the one place in the card where copy is allowed to be colourful.
  static List<InlineSpan> _captionSpans(String caption, Color accent) {
    final tokens = caption.split(RegExp(r'(?=\s)|(?<=\s)'));
    return [
      for (final token in tokens)
        if (token.startsWith('#') || token.startsWith('@'))
          TextSpan(
            text: token,
            // ds-ignore: no-hand-rolled-text-styles -- a TextSpan child is an
            // overlay on the parent span, so it must not carry a full role or
            // it overrides the caption size the caller chose.
            style: TextStyle(color: accent, fontWeight: DsTypography.semiBold),
          )
        else
          TextSpan(text: token),
    ];
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// "2h", "3d" — the time under a post's name.
String dsShortTimeAgo(BuildContext context, DateTime date) {
  final l10n = context.l10n;
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.shortMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.shortHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.shortDaysAgo(diff.inDays);
  return l10n.shortWeeksAgo((diff.inDays / 7).floor());
}
