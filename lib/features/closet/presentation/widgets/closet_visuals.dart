import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/media/authorized_media_image.dart';

/// How a slot looks when there is no photograph to show.
///
/// Presentation only, keyed on the server's closed slot vocabulary. A key the
/// app has not met yet falls back to the hanger rather than failing, so a new
/// slot added on the server draws as a plain garment until it is given its
/// own glyph here.
abstract final class ClosetSlotStyle {
  static IconData icon(String slot) => switch (slot) {
    'DRESS' => Icons.woman_rounded,
    'ABAYA' => Icons.woman_2_rounded,
    'TOP' => Icons.checkroom_rounded,
    'BOTTOM' => Icons.style_rounded,
    'OUTERWEAR' => Icons.dry_cleaning_rounded,
    'SHOES' => Icons.directions_walk_rounded,
    'BAG' => Icons.shopping_bag_rounded,
    'JEWELRY' => Icons.diamond_rounded,
    'ACCESSORY' => Icons.watch_rounded,
    'PERFUME' => Icons.spa_rounded,
    'BEAUTY' => Icons.face_retouching_natural_rounded,
    'GIFT' => Icons.redeem_rounded,
    _ => Icons.checkroom_rounded,
  };

  /// The tinted ground behind a piece with no photograph.
  ///
  /// Grouped by family rather than one colour per slot: a grid of twelve
  /// different hues reads as a toy box, three quiet families read as a
  /// wardrobe sorted by hand.
  static ({Color ground, Color ink}) tint(BuildContext context, String slot) {
    final c = context.dsColors;
    return switch (slot) {
      'DRESS' || 'ABAYA' || 'BEAUTY' || 'PERFUME' => (
        ground: c.primaryContainer,
        ink: c.onPrimaryContainer,
      ),
      'JEWELRY' || 'BAG' || 'GIFT' || 'ACCESSORY' => (
        ground: c.accentContainer,
        ink: c.onAccentContainer,
      ),
      'OUTERWEAR' || 'SHOES' => (
        ground: c.secondaryContainer,
        ink: c.onSecondaryContainer,
      ),
      _ => (ground: c.surfaceVariant, ink: c.onSurfaceVariant),
    };
  }
}

/// A garment's photograph, or the slot's art when there is none.
///
/// Every closet surface draws pieces through this, so a piece without a photo
/// looks deliberate — a tinted panel with its slot's glyph — rather than a
/// grey box with a broken-image icon in it.
class ClosetPhoto extends StatelessWidget {
  const ClosetPhoto({
    super.key,
    required this.url,
    required this.slot,
    this.width,
    this.blurHash,
    this.iconSize = DsSizes.iconLg,
  });

  final String? url;
  final String slot;
  final double? width;
  final String? blurHash;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fallback = ClosetPhotoFallback(slot: slot, iconSize: iconSize);
    final source = url;
    if (source == null || source.isEmpty) return fallback;

    // A personal photograph is a PRIVATE asset behind her session, which is
    // why this is not `Image.network`: that loader carries no bearer token
    // and gets a 401 for every wardrobe photo she has taken.
    return AuthorizedMediaImage(
      url: source,
      width: width,
      blurHash: blurHash,
      fallback: fallback,
    );
  }
}

class ClosetPhotoFallback extends StatelessWidget {
  const ClosetPhotoFallback({
    super.key,
    required this.slot,
    this.iconSize = DsSizes.iconLg,
  });

  final String slot;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tint = ClosetSlotStyle.tint(context, slot);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tint.ground, tint.ground.withValues(alpha: 0.55)],
        ),
      ),
      child: Center(
        child: Icon(
          ClosetSlotStyle.icon(slot),
          size: iconSize,
          color: tint.ink.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

/// What one cell of a collage holds.
enum ClosetCollageState {
  /// A piece she owns.
  owned,

  /// A piece she has chosen but not bought — drawn with a caution band, so a
  /// look never reads as finished while part of it is still in a shop.
  wanted,

  /// A slot nothing has been chosen for. Drawn as an open frame.
  missing,
}

class ClosetCollagePiece {
  const ClosetCollagePiece({
    required this.slot,
    required this.label,
    this.url,
    this.state = ClosetCollageState.owned,
  });

  final String slot;
  final String label;
  final String? url;
  final ClosetCollageState state;
}

/// An outfit as one picture: up to four pieces laid out like a flat-lay.
///
/// One piece fills the frame; two sit side by side; three put the first —
/// the anchor, which the server sends first — in a tall cell beside two small
/// ones; four make a grid. A fifth and beyond are counted on the last cell
/// rather than squeezed in, because a collage of postage stamps shows nothing.
class ClosetCollage extends StatelessWidget {
  const ClosetCollage({
    super.key,
    required this.pieces,
    this.radius = DsRadius.lg,
    this.wantedLabel,
  });

  final List<ClosetCollagePiece> pieces;
  final double radius;

  /// The caption on a wanted cell. Passed in so the widget needs no l10n.
  final String? wantedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final shown = pieces.take(4).toList(growable: false);
    final overflow = pieces.length - shown.length;

    Widget cell(int index) => SizedBox.expand(
      child: _CollageCell(
        piece: shown[index],
        wantedLabel: wantedLabel,
        overflow: index == shown.length - 1 ? overflow : 0,
      ),
    );

    const gap = DsSpacing.xxxs;
    final Widget layout = switch (shown.length) {
      0 => ClosetPhotoFallback(slot: '', iconSize: DsSizes.iconXl),
      1 => cell(0),
      2 => Row(
        children: [
          Expanded(child: cell(0)),
          DsGaps.hXxxs,
          Expanded(child: cell(1)),
        ],
      ),
      3 => Row(
        children: [
          Expanded(flex: 3, child: cell(0)),
          DsGaps.hXxxs,
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: cell(1)),
                DsGaps.vXxxs,
                Expanded(child: cell(2)),
              ],
            ),
          ),
        ],
      ),
      _ => Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: cell(0)),
                DsGaps.hXxxs,
                Expanded(child: cell(1)),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: cell(2)),
                DsGaps.hXxxs,
                Expanded(child: cell(3)),
              ],
            ),
          ),
        ],
      ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: colors.surface, child: layout),
    );
  }
}

class _CollageCell extends StatelessWidget {
  const _CollageCell({
    required this.piece,
    required this.wantedLabel,
    required this.overflow,
  });

  final ClosetCollagePiece piece;
  final String? wantedLabel;
  final int overflow;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;

    if (piece.state == ClosetCollageState.missing) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.45),
          border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
        ),
        padding: const EdgeInsets.all(DsSpacing.xxs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: DsSizes.iconSm,
              color: colors.onSurfaceVariant,
            ),
            DsGaps.vXxxs,
            Text(
              piece.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.micro.tint(colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClosetPhoto(url: piece.url, slot: piece.slot, iconSize: DsSizes.iconMd),
        if (piece.state == ClosetCollageState.wanted && wantedLabel != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: colors.warning.withValues(alpha: 0.92),
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxxs),
              child: Text(
                wantedLabel!,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: text.micro.tint(colors.onWarning),
              ),
            ),
          ),
        if (overflow > 0)
          ColoredBox(
            color: DsColors.mediaScrim,
            child: Center(
              child: Text(
                '+$overflow',
                style: text.metricSmall.tint(DsColors.onMedia),
              ),
            ),
          ),
      ],
    );
  }
}

/// A small rounded pill — a status, a count, a hint — tinted by tone.
class ClosetPill extends StatelessWidget {
  const ClosetPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = DsTone.neutral,
    this.onMedia = false,
  });

  final String label;
  final IconData? icon;
  final DsTone tone;

  /// Over a photograph: a frosted dark pill with light ink, whatever the tone.
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final ink = onMedia ? DsColors.onMedia : context.toneColor(tone);
    final fill = onMedia ? DsColors.mediaScrim : context.toneContainer(tone);

    return Container(
      padding: DsSpacing.pillPadding,
      decoration: BoxDecoration(color: fill, borderRadius: DsRadius.borderPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: DsSizes.iconXxs, color: ink),
            DsGaps.hXxs,
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.badge.tint(ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The closet's section heading: an eyebrow, a title, and an optional action.
class ClosetSectionHeading extends StatelessWidget {
  const ClosetSectionHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!, style: text.overline.tint(palette.primary)),
                  DsGaps.vXxxs,
                ],
                Text(title, style: text.sectionTitle.tint(palette.ink)),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: text.link),
            ),
        ],
      ),
    );
  }
}
