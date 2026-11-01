import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';

/// Ohara's post: the photograph is the card.
///
/// The card it replaces was a white frame around an inset picture, a header
/// above it, a row of glyphs under it and the words under those — the shape
/// of every social app of the last decade. Here everything lives on the
/// image, the way a magazine cover holds its masthead and its lines:
///
/// - a frosted **capsule** at the top: who is speaking, in a gradient ring,
///   and how long ago;
/// - **segments** across the top for a gallery, the way stories count;
/// - a vertical **rail** of actions at the end — love, talk, share, put it on
///   her page, keep it — each with its count;
/// - the **caption** on the shade at the foot, hashtags in champagne;
/// - the piece itself as a frosted **ticket**: its name, its price and the bag,
///   so seeing it and buying it stay the same gesture.
///
/// A post with no picture and no piece becomes a painted **note** in the
/// display serif. Double-tap is love everywhere, with the petal burst.
///
/// One card for every surface that tells something as a post — a boutique's
/// post on the home feed, a product told as a post on a department page or in
/// search, and the community's content — so they cannot drift apart again.
/// Everything is presentational: counts, flags and callbacks come in.
class DsImmersivePost extends StatefulWidget {
  const DsImmersivePost({
    super.key,
    required this.authorName,
    required this.subtitle,
    required this.media,
    required this.caption,
    required this.liked,
    required this.saved,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.burst,
    required this.onLike,
    required this.onDoubleTap,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    this.authorImageUrl,
    this.authorVerified = false,
    this.onAuthor,
    this.onMore,
    this.product,
    this.onOpenProduct,
    this.onAddToBag,
    this.morePieces = 0,
    this.onShowAllPieces,
    this.onOpenMedia,
    this.reaction,
    this.reactionSummary = const [],
    this.onReact,
    this.picked = false,
    this.onPick,
    this.isFresh = false,
    this.featured = false,
    this.mediaOverride,
    this.badges = const [],
    this.banner,
    this.footer,
  });

  final String authorName;
  final String subtitle;
  final String? authorImageUrl;
  final bool authorVerified;
  final VoidCallback? onAuthor;

  /// The «…» menu; hidden when null.
  final VoidCallback? onMore;

  /// The gallery. When empty and a [product] is given, the product's own
  /// photographs stand in, so a post never shows a blank plate when the piece
  /// it is about has pictures.
  final List<MediaItem> media;

  /// Replaces the gallery — a reel's player, for instance.
  final Widget? mediaOverride;

  final Product? product;
  final VoidCallback? onOpenProduct;

  /// Null when nothing is in stock to add; the ticket then only navigates.
  final VoidCallback? onAddToBag;

  /// Pieces tagged beyond [product]. A post can carry several; the ticket
  /// shows the first and a «+N» that opens them all through
  /// [onShowAllPieces]. Only the first used to reach the screen.
  final int morePieces;
  final VoidCallback? onShowAllPieces;

  /// A tap on the picture of a post with no piece in it opens the photo, as
  /// on any social app; with a piece, the tap still opens the piece. Given
  /// the index of the photo on screen.
  final ValueChanged<int>? onOpenMedia;

  /// Reactions, Facebook's way: when [onReact] is set the heart becomes a
  /// reaction button — a tap for ❤️ or to take hers back, a long press for
  /// the bar — and shows the glyph she left ([reaction]). [onReact] receives
  /// the chosen glyph, or null to clear. Without it the heart only likes.
  final String? reaction;
  final List<ReactionCount> reactionSummary;
  final ValueChanged<String?>? onReact;

  final String caption;

  final bool liked;
  final bool saved;
  final bool picked;
  final int likes;
  final int comments;
  final int shares;

  final VoidCallback onLike;
  final VoidCallback onDoubleTap;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  /// «أضيفي إلى صفحتي». Null hides it — her own post cannot go on her page.
  final VoidCallback? onPick;

  /// The heart burst, owned by the caller so a like from anywhere can play it.
  final AnimationController burst;

  /// Posted within the last few days — earns the champagne «جديد» ribbon.
  final bool isFresh;

  /// The first card of a run: a brand ring and a warmer glow.
  final bool featured;

  /// Extra chips under the capsule (e.g. «قيد المراجعة»).
  final List<Widget> badges;

  /// Shown above the card — who put a reshared post on her page.
  final Widget? banner;

  /// Shown under the card — the closet strip, for instance.
  final Widget? footer;

  @override
  State<DsImmersivePost> createState() => _DsImmersivePostState();
}

class _DsImmersivePostState extends State<DsImmersivePost> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _expanded = false;

  /// Portrait, a touch taller than 4:5 so the rail and the ticket never
  /// crowd the face of the picture.
  static const double _aspect = 0.76;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<MediaItem> get _media {
    if (widget.media.isNotEmpty) return widget.media;
    return widget.product?.media ?? const [];
  }

  bool get _isNote =>
      widget.mediaOverride == null && _media.isEmpty && widget.product == null;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    final card = AspectRatio(
      aspectRatio: _aspect,
      child: GestureDetector(
        onTap: widget.product != null
            ? widget.onOpenProduct
            : widget.onOpenMedia == null ||
                  widget.mediaOverride != null ||
                  _media.isEmpty
            ? null
            : () => widget.onOpenMedia!(_index),
        onDoubleTap: widget.onDoubleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _surface(context),
            // Shade at the head so the capsule reads, and a deeper one at the
            // foot for the words, the rail and the ticket.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.22, 0.48, 1],
                    colors: [
                      DsColors.mediaScrim,
                      DsColors.transparent,
                      DsColors.transparent,
                      DsColors.mediaGround,
                    ],
                  ),
                ),
              ),
            ),
            if (_media.length > 1 && widget.mediaOverride == null)
              PositionedDirectional(
                top: DsSpacing.sm,
                start: DsSpacing.md,
                end: DsSpacing.md,
                child: _Segments(count: _media.length, index: _index),
              ),
            PositionedDirectional(
              top: DsSpacing.lg,
              start: DsSpacing.sm,
              end: DsSpacing.sm,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Capsule(
                          name: widget.authorName,
                          subtitle: widget.subtitle,
                          imageUrl: widget.authorImageUrl,
                          verified: widget.authorVerified,
                          onTap: widget.onAuthor,
                        ),
                        if (_badges(context).isNotEmpty) ...[
                          DsGaps.vXs,
                          Wrap(
                            spacing: DsSpacing.xxs,
                            runSpacing: DsSpacing.xxs,
                            children: _badges(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.onMore != null) ...[
                    DsGaps.hXs,
                    _GlassCircle(
                      icon: Icons.more_horiz_rounded,
                      label: l10n.postOptions,
                      onTap: widget.onMore!,
                    ),
                  ],
                ],
              ),
            ),
            PositionedDirectional(
              start: DsSpacing.md,
              end: DsSpacing.sm,
              bottom: DsSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _isNote
                            ? const SizedBox.shrink()
                            : _caption(context),
                      ),
                      DsGaps.hSm,
                      _rail(context),
                    ],
                  ),
                  if (widget.product case final product?) ...[
                    DsGaps.vSm,
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: DsSpacing.xxs,
                      ),
                      child: _Ticket(
                        product: product,
                        onTap: widget.onOpenProduct,
                        onAddToBag: widget.onAddToBag,
                        morePieces: widget.morePieces,
                        onShowAll: widget.onShowAllPieces,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IgnorePointer(
              child: Center(
                child: DsLoveBurst(controller: widget.burst, color: c.favorite),
              ),
            ),
          ],
        ),
      ),
    );

    final framed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxxl,
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: widget.featured ? 0.26 : 0.12),
            blurRadius: widget.featured ? DsBlur.extreme : DsBlur.intense,
            offset: const Offset(0, DsSpacing.md),
          ),
          BoxShadow(
            color: c.shadow,
            blurRadius: DsBlur.medium,
            offset: const Offset(0, DsSpacing.xs),
          ),
        ],
      ),
      child: widget.featured
          ? DsGradientBorder(
              radius: DsRadius.xxxl,
              width: DsSpacing.xxxs,
              gradient: CustomerExperience.signatureGradient,
              child: ClipRRect(borderRadius: DsRadius.borderXxxl, child: card),
            )
          : ClipRRect(borderRadius: DsRadius.borderXxxl, child: card),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.banner != null) ...[widget.banner!, DsGaps.vXs],
        framed,
        _Meta(
          likes: widget.likes,
          comments: widget.comments,
          onComments: widget.onComment,
          reactionSummary: widget.onReact == null ? null : widget.reactionSummary,
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }

  List<Widget> _badges(BuildContext context) => [
    if (widget.product case final product? when product.hasDiscount)
      DsDiscountBadge(percentOff: product.discountPercent),
    if (widget.isFresh) const _FreshRibbon(),
    ...widget.badges,
  ];

  Widget _surface(BuildContext context) {
    if (widget.mediaOverride != null) return widget.mediaOverride!;
    if (_isNote) return _Note(caption: widget.caption);
    final media = _media;
    if (media.isEmpty) return const DsMediaFallback();
    return PageView.builder(
      controller: _pages,
      physics: media.length > 1 ? null : const NeverScrollableScrollPhysics(),
      onPageChanged: (i) => setState(() => _index = i),
      itemCount: media.length,
      itemBuilder: (_, i) => DsMediaFrame(item: media[i]),
    );
  }

  Widget _caption(BuildContext context) {
    final caption = widget.caption.trim();
    if (caption.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final style = context.dsText.body
        .tint(DsColors.onMedia)
        .copyWith(
          height: 1.45,
          shadows: const [
            Shadow(blurRadius: DsBlur.subtle, color: DsColors.mediaScrim),
          ],
        );
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: DsMotion.moderate,
        curve: DsMotion.emphasized,
        alignment: Alignment.bottomCenter,
        child: RichText(
          maxLines: _expanded ? 8 : 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: style,
            children: [
              ..._spans(caption),
              if (!_expanded && caption.length > 70)
                TextSpan(
                  text: '  ${l10n.postMore}',
                  style: style.copyWith(color: DsColors.onMediaMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hashtags and mentions in champagne — the one place the words may shine.
  static List<InlineSpan> _spans(String caption) {
    final tokens = caption.split(RegExp(r'(?=\s)|(?<=\s)'));
    return [
      for (final token in tokens)
        if (token.startsWith('#') || token.startsWith('@'))
          TextSpan(
            text: token,
            style: const TextStyle(
              color: DsColors.gold200,
              fontWeight: DsTypography.semiBold,
            ),
          )
        else
          TextSpan(text: token),
    ];
  }

  Widget _rail(BuildContext context) {
    final l10n = context.l10n;
    final c = context.dsColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onReact case final onReact?)
          _RailButton(
            icon: Icons.favorite_border_rounded,
            glyph: widget.reaction,
            active: widget.reaction != null,
            activeColor: c.favorite,
            count: widget.likes,
            label: widget.reaction == null
                ? l10n.reactionLove
                : DsReactions.label(l10n, widget.reaction!),
            onTap: () =>
                onReact(widget.reaction == null ? DsReactions.like : null),
            onLongPress: (anchor) async {
              final chosen = await DsReactionPicker.show(
                context,
                anchor: anchor,
                current: widget.reaction,
              );
              if (chosen == null) return;
              onReact(chosen == widget.reaction ? null : chosen);
            },
          )
        else
          _RailButton(
            icon: widget.liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            active: widget.liked,
            activeColor: c.favorite,
            count: widget.likes,
            label: l10n.a11yLike,
            onTap: widget.onLike,
          ),
        _RailButton(
          icon: Icons.mode_comment_outlined,
          count: widget.comments,
          label: l10n.comments,
          onTap: widget.onComment,
        ),
        _RailButton(
          icon: Icons.ios_share_rounded,
          count: widget.shares,
          label: l10n.contentShare,
          onTap: widget.onShare,
        ),
        if (widget.onPick != null)
          _RailButton(
            icon: widget.picked
                ? Icons.library_add_check_rounded
                : Icons.add_to_photos_outlined,
            active: widget.picked,
            activeColor: DsColors.gold200,
            label: l10n.contentAddToMyPage,
            onTap: widget.onPick!,
          ),
        _RailButton(
          icon: widget.saved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          active: widget.saved,
          activeColor: DsColors.gold200,
          label: l10n.a11ySave,
          onTap: widget.onSave,
          last: true,
        ),
      ],
    );
  }
}

/// Who is speaking: avatar in the brand ring, name, verified mark, time.
class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.verified,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool verified;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: DsRadius.borderFull,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.xxs,
              DsSpacing.xxs,
              DsSpacing.md,
              DsSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: DsColors.mediaGround.withValues(alpha: 0.28),
              borderRadius: DsRadius.borderFull,
              border: Border.all(color: DsColors.onMediaFaint),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(DsSpacing.xxxs),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CustomerExperience.signatureGradient,
                  ),
                  child: DsAvatar(
                    imageUrl: imageUrl,
                    name: name,
                    size: DsSizes.avatarSm,
                  ),
                ),
                DsGaps.hXs,
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.dsText.labelStrong.displayFamily
                                  .tint(DsColors.onMedia),
                            ),
                          ),
                          if (verified) ...[
                            DsGaps.hXxs,
                            const Icon(
                              Icons.verified_rounded,
                              size: DsSizes.iconXxs + DsSpacing.xxxs,
                              color: DsColors.gold200,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.micro.tint(DsColors.onMediaMuted),
                      ),
                    ],
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

/// Gallery position as thin segments across the top, the way stories count.
class _Segments extends StatelessWidget {
  const _Segments({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) DsGaps.hXxs,
          Expanded(
            child: AnimatedContainer(
              duration: DsMotion.normal,
              height: DsSpacing.xxxs + 1,
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderFull,
                color: i == index ? DsColors.onMedia : DsColors.onMediaFaint,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: DsBlur.light,
              sigmaY: DsBlur.light,
            ),
            child: Container(
              width: DsSizes.controlSm,
              height: DsSizes.controlSm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DsColors.mediaGround.withValues(alpha: 0.28),
                border: Border.all(color: DsColors.onMediaFaint),
              ),
              child: Icon(icon, color: DsColors.onMedia, size: DsSizes.iconSm),
            ),
          ),
        ),
      ),
    );
  }
}

/// One action on the rail: a frosted disc, its glyph, its count below.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.active = false,
    this.activeColor,
    this.last = false,
    this.glyph,
    this.onLongPress,
  });

  final IconData icon;

  /// An emoji drawn instead of [icon] — the reaction she left.
  final String? glyph;

  /// Given the button's rect on screen, to anchor a picker to it.
  final ValueChanged<Rect>? onLongPress;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool active;
  final Color? activeColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? DsColors.onMedia) : DsColors.onMedia;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : DsSpacing.xs),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress == null
              ? null
              : () {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  onLongPress!(box.localToGlobal(Offset.zero) & box.size);
                },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: DsBlur.light,
                    sigmaY: DsBlur.light,
                  ),
                  child: AnimatedContainer(
                    duration: DsMotion.fast,
                    width: DsSizes.controlMd,
                    height: DsSizes.controlMd,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? color.withValues(alpha: 0.22)
                          : DsColors.mediaGround.withValues(alpha: 0.26),
                      border: Border.all(
                        color: active
                            ? color.withValues(alpha: 0.7)
                            : DsColors.onMediaFaint,
                      ),
                    ),
                    child: AnimatedScale(
                      scale: active ? 1.12 : 1,
                      duration: DsMotion.fast,
                      curve: DsMotion.softSpring,
                      child: glyph != null
                          ? Text(
                              glyph!,
                              style: const TextStyle(fontSize: 20, height: 1.1),
                              textScaler: TextScaler.noScaling,
                            )
                          : Icon(icon, size: DsSizes.iconSm + 2, color: color),
                    ),
                  ),
                ),
              ),
              if (count != null && count! > 0) ...[
                DsGaps.vXxxs,
                Text(
                  formatCount(count!),
                  style: context.dsText.micro.bold
                      .tint(DsColors.onMedia)
                      .copyWith(
                        shadows: const [
                          Shadow(
                            blurRadius: DsBlur.subtle,
                            color: DsColors.mediaScrim,
                          ),
                        ],
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

/// The piece, as a frosted ticket: name, price, and the bag.
class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.product,
    required this.onTap,
    required this.onAddToBag,
    this.morePieces = 0,
    this.onShowAll,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToBag;
  final int morePieces;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: DsRadius.borderXl,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.heavy, sigmaY: DsBlur.heavy),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.md,
              DsSpacing.xs,
              DsSpacing.xs,
              DsSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderXl,
              color: DsColors.white.withValues(alpha: 0.14),
              border: Border.all(color: DsColors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.labelStrong.tint(
                          DsColors.onMedia,
                        ),
                      ),
                      DsGaps.vXxxs,
                      Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: Text(
                              product.price?.format() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.price(
                                DsColors.gold200,
                                size: DsTypography.titleMedium,
                              ),
                            ),
                          ),
                          if (product.hasDiscount) ...[
                            DsGaps.hXs,
                            Flexible(
                              flex: 2,
                              child: Text(
                                product.compareAtPrice?.format() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.priceStrike(
                                  DsColors.onMediaMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (morePieces > 0 && onShowAll != null) ...[
                  DsGaps.hXs,
                  Semantics(
                    button: true,
                    label: l10n.postTaggedPiecesTitle,
                    child: GestureDetector(
                      onTap: onShowAll,
                      child: Container(
                        height: DsSizes.controlMd,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.sm,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DsColors.white.withValues(alpha: 0.22),
                          borderRadius: DsRadius.borderLg,
                          border: Border.all(
                            color: DsColors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          l10n.postMorePieces(morePieces),
                          style: context.dsText.labelStrong.tint(
                            DsColors.onMedia,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                DsGaps.hXs,
                Semantics(
                  button: true,
                  label: onAddToBag != null
                      ? l10n.addToCart
                      : l10n.postOpenPiece,
                  child: GestureDetector(
                    onTap: onAddToBag ?? onTap,
                    child: Container(
                      width: DsSizes.controlMd,
                      height: DsSizes.controlMd,
                      decoration: BoxDecoration(
                        color: DsColors.white,
                        borderRadius: DsRadius.borderLg,
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.35),
                            blurRadius: DsBlur.light,
                          ),
                        ],
                      ),
                      child: Icon(
                        onAddToBag != null
                            ? Icons.shopping_bag_outlined
                            : Icons.arrow_forward_rounded,
                        color: c.primary,
                        size: DsSizes.iconSm,
                      ),
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

/// A post of words alone, set like a pull-quote on a painted ground.
class _Note extends StatelessWidget {
  const _Note({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [DsColors.secondary800, DsColors.primary700, DsColors.rosewood],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: DsSpacing.massive + DsSpacing.lg,
            start: DsSpacing.lg,
            child: Text(
              '”',
              style: context.dsText.hero.displayFamily
                  .tint(DsColors.onMediaFaint)
                  .copyWith(height: 1, fontSize: DsTypography.displayLarge * 2),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.xl,
                DsSpacing.massive,
                DsSpacing.massive,
                DsSpacing.massive,
              ),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.screenTitle.displayFamily
                    .tint(DsColors.onMedia)
                    .copyWith(height: 1.55),
              ),
            ),
          ),
          const PositionedDirectional(
            bottom: DsSpacing.xl,
            start: DsSpacing.xl,
            child: DsSparkle(size: DsSizes.iconSm, color: DsColors.gold200),
          ),
        ],
      ),
    );
  }
}

/// Under the card: how many loved it, and the way into the conversation.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.likes,
    required this.comments,
    required this.onComments,
    this.reactionSummary,
  });

  /// Set for a post with reactions: drawn as «❤️😍🔥 ١٢» instead of hearts.
  final List<ReactionCount>? reactionSummary;
  final int likes;
  final int comments;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.sm,
        DsSpacing.sm,
        DsSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          if (likes > 0 && reactionSummary != null) ...[
            DsReactionSummary(summary: reactionSummary!, total: likes),
            DsGaps.hSm,
          ] else if (likes > 0) ...[
            _HeartStack(color: c.favorite),
            DsGaps.hXs,
            Text(
              l10n.postLikesCount(formatCount(likes)),
              style: context.dsText.labelStrong.tint(c.onSurface),
            ),
            DsGaps.hSm,
          ],
          Expanded(
            child: GestureDetector(
              onTap: onComments,
              behavior: HitTestBehavior.opaque,
              child: Text(
                comments > 0
                    ? l10n.postViewComments(formatCount(comments))
                    : l10n.beTheFirstToComment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: likes > 0 ? TextAlign.end : TextAlign.start,
                style: context.dsText.caption.tint(c.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three overlapping hearts — a crowd, drawn small.
class _HeartStack extends StatelessWidget {
  const _HeartStack({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = DsSizes.iconXs + DsSpacing.xxs;
    final shades = [color, DsColors.rosewood, DsColors.gold300];
    return SizedBox(
      width: size + DsSpacing.sm * 2,
      height: size,
      child: Stack(
        children: [
          for (var i = shades.length - 1; i >= 0; i--)
            PositionedDirectional(
              start: DsSpacing.sm * i,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shades[i],
                  border: Border.all(
                    color: context.dsColors.background,
                    width: DsSpacing.xxxs / 1.5,
                  ),
                ),
                child: Icon(
                  i == 0 ? Icons.favorite_rounded : Icons.auto_awesome_rounded,
                  size: size * 0.55,
                  color: DsColors.onMedia,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A champagne «جديد» ribbon for a post only a few days old.
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DsSparkle(
            size: DsSizes.iconXxs - 3,
            color: DsColors.onChampagne,
          ),
          DsGaps.hXxs,
          Text(
            context.l10n.justIn,
            style: context.dsText.badge.tint(DsColors.onChampagne),
          ),
        ],
      ),
    );
  }
}
