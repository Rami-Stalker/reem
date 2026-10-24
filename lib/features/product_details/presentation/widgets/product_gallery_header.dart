import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/router/open_route.dart';
import 'package:ohara/core/shared/entities/media.dart';

/// The product's own photographs, full-bleed, swipeable.
///
/// This replaces a header that showed one hard-coded Unsplash dress to every
/// product in the catalogue. The chrome over it — back, favourite, share — is
/// the app's [DsIconButton] on the glass variant, so it reads the same as the
/// controls floating over any other image in Ohara.
///
/// **Why there is a thumbnail rail.** A swipe was the only way to reach the
/// second and third photograph, and the only hint that they existed was a row
/// of small dots over a busy image — so shoppers reported the page as having
/// one picture. The rail says how many there are, shows what they are, and
/// reaches them with a tap; the counter pill repeats the count where the eye
/// already is. Tapping the photograph opens it full screen, where it can be
/// pinched.
class ProductGalleryHeader extends StatefulWidget {
  const ProductGalleryHeader({
    super.key,
    required this.media,
    required this.title,
    this.isSaved = false,
    this.discountPercent = 0,
    this.onToggleSave,
    this.onShare,
  });

  final List<MediaItem> media;
  final String title;

  /// «المفضّلة» — her private shelf, which is *not* the like.
  ///
  /// This control was a heart, and the heart on a catalogue tile is now the
  /// product's public like. Two hearts, two meanings, one product: she would
  /// fill one on the grid, open the piece, and find the other one empty. The
  /// bookmark is what the post action bar below already uses for saving, so
  /// the page says the same thing twice rather than two different things.
  final bool isSaved;
  final int discountPercent;
  final VoidCallback? onToggleSave;
  final VoidCallback? onShare;

  /// Height of the thumbnail rail, including its padding.
  static const double _railHeight = 84;
  static const double _thumbSize = 62;

  @override
  State<ProductGalleryHeader> createState() => _ProductGalleryHeaderState();
}

class _ProductGalleryHeaderState extends State<ProductGalleryHeader> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _index = index);
    _controller.animateToPage(
      index,
      duration: DsMotion.moderate,
      curve: DsMotion.silk,
    );
  }

  void _openFullScreen() {
    if (widget.media.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGallery(
          media: widget.media,
          initialIndex: _index,
          title: widget.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final media = widget.media;
    final hasRail = media.length > 1;
    // Portrait, because that is how clothing photographs and how the rest of
    // the catalogue is cropped. The rail sits under the plate, inside the same
    // expanded header.
    final imageHeight =
        MediaQuery.sizeOf(context).width / DsSizes.aspectPortrait;
    final height =
        imageHeight + (hasRail ? ProductGalleryHeader._railHeight : 0);

    return SliverAppBar(
      expandedHeight: height,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      leadingWidth: DsSizes.minTouchTarget + DsSpacing.md,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: DsSpacing.xs),
        child: DsIconButton(
          icon: DsIcons.back,
          variant: DsIconButtonVariant.glass,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          // A product page is the most-shared screen in the app, so it is the
          // one most often opened with nothing underneath it.
          onPressed: () => popOrHome(context),
        ),
      ),
      actions: [
        DsIconButton(
          icon: widget.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          variant: DsIconButtonVariant.glass,
          tooltip: widget.isSaved ? l10n.unfavorite : l10n.favorite,
          color: widget.isSaved ? colors.favorite : null,
          onPressed: widget.onToggleSave,
        ),
        DsGaps.hXs,
        DsIconButton(
          icon: DsIcons.share,
          variant: DsIconButtonVariant.glass,
          tooltip: l10n.a11yShare,
          onPressed: widget.onShare,
        ),
        DsGaps.hXs,
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.isEmpty)
                    _MissingPhoto(title: widget.title)
                  else
                    GestureDetector(
                      onTap: _openFullScreen,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: media.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _Frame(
                          item: media[i],
                          title: widget.title,
                          width: MediaVariants.medium,
                        ),
                      ),
                    ),

                  // Scrims at both ends so the floating chrome and the page
                  // below stay legible over a pale photograph.
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: DsGradients.imageScrimTop,
                      ),
                    ),
                  ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: DsGradients.imageScrim,
                      ),
                    ),
                  ),

                  if (widget.discountPercent > 0)
                    PositionedDirectional(
                      start: DsSpacing.lg,
                      bottom: DsSpacing.lg,
                      child: DsDiscountBadge(
                        percentOff: widget.discountPercent,
                      ),
                    ),

                  if (media.length > 1)
                    PositionedDirectional(
                      end: DsSpacing.lg,
                      bottom: DsSpacing.lg,
                      child: Semantics(
                        label: l10n.galleryPhotoPosition(
                          _index + 1,
                          media.length,
                        ),
                        child: DsCounterPill(
                          index: _index,
                          count: media.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasRail)
              SizedBox(
                height: ProductGalleryHeader._railHeight,
                child: ColoredBox(
                  color: colors.surface,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.lg,
                      vertical: DsSpacing.sm,
                    ),
                    itemCount: media.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: DsSpacing.xs),
                    itemBuilder: (context, i) => _Thumb(
                      item: media[i],
                      title: widget.title,
                      selected: i == _index,
                      position: i + 1,
                      total: media.length,
                      onTap: () => _goTo(i),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One photograph, at the width the surface actually draws it.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.item,
    required this.title,
    required this.width,
    this.fit = BoxFit.cover,
  });

  final MediaItem item;
  final String title;
  final int width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return CachedNetworkImage(
      imageUrl: MediaVariants.at(item.displayUrl, width),
      // The same number that chose the variant. Asking for a 720px copy and
      // then decoding it at whatever the source happened to be is the one
      // mistake this pairing exists to prevent.
      memCacheWidth: width,
      fit: fit,
      fadeInDuration: DsMotion.normal,
      placeholder: (_, _) =>
          DsShimmer(child: ColoredBox(color: colors.surfaceVariant)),
      errorWidget: (_, _, _) => _MissingPhoto(title: title),
    );
  }
}

/// One frame of the rail — the fastest way to the photograph she wants.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.item,
    required this.title,
    required this.selected,
    required this.position,
    required this.total,
    required this.onTap,
  });

  final MediaItem item;
  final String title;
  final bool selected;
  final int position;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.galleryPhotoPosition(position, total),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DsMotion.fast,
          width: ProductGalleryHeader._thumbSize,
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderMd,
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: MediaVariants.thumb(item.displayUrl),
                fit: BoxFit.cover,
                memCacheWidth: MediaDecode.widthFor(
                  context,
                  ProductGalleryHeader._thumbSize,
                ),
                placeholder: (_, _) => ColoredBox(color: colors.shimmerBase),
                errorWidget: (_, _, _) =>
                    ColoredBox(color: colors.surfaceVariant),
              ),
              if (item.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: DsColors.onMedia,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photographs on their own, over black, where they can be pinched.
class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({
    required this.media,
    required this.initialIndex,
    required this.title,
  });

  final List<MediaItem> media;
  final int initialIndex;
  final String title;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: DsColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: DsColors.onMedia,
        elevation: 0,
        title: Text(
          l10n.galleryPhotoPosition(_index + 1, widget.media.length),
          style: context.dsText.labelLarge.tint(DsColors.onMedia),
        ),
        leading: IconButton(
          tooltip: l10n.galleryClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.media.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: _Frame(
            item: widget.media[i],
            title: widget.title,
            width: MediaVariants.medium,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ColoredBox(
      color: colors.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: DsSizes.iconXl,
          color: colors.onSurfaceVariant,
          semanticLabel: title,
        ),
      ),
    );
  }
}
