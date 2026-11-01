import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The reactions a woman can leave — on a post, a reel, a story or a comment.
///
/// One list, here, so every surface offers the same set and a new reaction is
/// added in one place: append its glyph to [all] and name it in [label].
/// On the wire the heart is "no emoji" (a plain like), so a reaction left by
/// an older build that only knew the heart reads as ❤️ here.
abstract final class DsReactions {
  static const like = '❤️';

  static const all = ['❤️', '😍', '🔥', '👏', '😂', '😮', '😢'];

  /// What the server stores for [emoji]: null for the heart.
  static String? toWire(String emoji) => emoji == like ? null : emoji;

  /// The glyph to draw for a reaction she left, or null for none.
  static String? glyphOf({required bool reacted, String? myReaction}) =>
      reacted ? (myReaction ?? like) : null;

  static String label(AppLocalizations l10n, String emoji) => switch (emoji) {
    '❤️' => l10n.reactionLove,
    '😍' => l10n.reactionGorgeous,
    '🔥' => l10n.reactionFire,
    '👏' => l10n.reactionBravo,
    '😂' => l10n.reactionHaha,
    '😮' => l10n.reactionWow,
    '😢' => l10n.reactionSad,
    _ => emoji,
  };
}

/// The bar of reactions that rises over a held heart — Facebook's gesture.
///
/// Anchored above [anchor] (global coordinates), kept on screen, and closed
/// by a tap anywhere else. Resolves to the chosen glyph, or null if she let
/// it go.
abstract final class DsReactionPicker {
  static Future<String?> show(
    BuildContext context, {
    required Rect anchor,
    String? current,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<String?>();
    late final OverlayEntry entry;
    void close(String? value) {
      if (completer.isCompleted) return;
      entry.remove();
      completer.complete(value);
    }

    entry = OverlayEntry(
      builder: (_) =>
          _PickerLayer(anchor: anchor, current: current, onClose: close),
    );
    unawaited(HapticFeedback.mediumImpact());
    overlay.insert(entry);
    return completer.future;
  }
}

class _PickerLayer extends StatelessWidget {
  const _PickerLayer({
    required this.anchor,
    required this.current,
    required this.onClose,
  });

  final Rect anchor;
  final String? current;
  final ValueChanged<String?> onClose;

  static const double _cell = 46;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final count = DsReactions.all.length;
    final width = _cell * count + DsSpacing.sm * 2;
    const height = _cell + DsSpacing.sm * 2;
    final left = (anchor.center.dx - width / 2).clamp(
      DsSpacing.sm,
      size.width - width - DsSpacing.sm,
    );
    // Above the heart, or below it when there is no room above.
    final above = anchor.top - height - DsSpacing.xs;
    final top = above > padding.top + DsSpacing.sm
        ? above
        : anchor.bottom + DsSpacing.xs;
    final colors = context.dsColors;
    final l10n = context.l10n;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onClose(null),
            onPanStart: (_) => onClose(null),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: DsMotion.normal,
            curve: DsMotion.softSpring,
            builder: (context, t, child) => Opacity(
              opacity: ((t - 0.6) / 0.4).clamp(0, 1),
              child: Transform.scale(scale: t, child: child),
            ),
            child: Material(
              color: colors.surface,
              elevation: 8,
              shadowColor: colors.shadow,
              borderRadius: DsRadius.borderFull,
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, emoji) in DsReactions.all.indexed)
                      _PickerCell(
                        emoji: emoji,
                        label: DsReactions.label(l10n, emoji),
                        selected: emoji == current,
                        delay: Duration(milliseconds: 30 * index),
                        size: _cell,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onClose(emoji);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerCell extends StatefulWidget {
  const _PickerCell({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.delay,
    required this.size,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final Duration delay;
  final double size;
  final VoidCallback onTap;

  @override
  State<_PickerCell> createState() => _PickerCellState();
}

class _PickerCellState extends State<_PickerCell> {
  bool _shown = false;
  bool _pressed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final scale = !_shown ? 0.3 : (_pressed ? 1.35 : 1.0);
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedScale(
              scale: scale,
              duration: DsMotion.fast,
              curve: DsMotion.softSpring,
              child: Container(
                alignment: Alignment.center,
                decoration: widget.selected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.12),
                      )
                    : null,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 28, height: 1.1),
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «❤️😍🔥 ١٢» — the most chosen reactions, overlapping, then the total.
class DsReactionSummary extends StatelessWidget {
  const DsReactionSummary({
    super.key,
    required this.summary,
    required this.total,
    this.onMedia = false,
    this.dense = false,
  });

  final List<ReactionCount> summary;
  final int total;

  /// Over a photograph rather than on a card.
  final bool onMedia;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final colors = context.dsColors;
    final glyphs = [
      for (final r in summary.take(3)) r.emoji,
      if (summary.isEmpty) DsReactions.like,
    ];
    final size = dense ? 16.0 : 20.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size + (glyphs.length - 1) * size * 0.62,
          height: size,
          child: Stack(
            children: [
              for (final (index, glyph) in glyphs.indexed)
                PositionedDirectional(
                  start: index * size * 0.62,
                  child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onMedia ? DsColors.mediaGround : colors.surface,
                      border: Border.all(
                        color: onMedia ? DsColors.mediaGround : colors.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      glyph,
                      style: TextStyle(fontSize: size * 0.68, height: 1),
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
            ],
          ),
        ),
        DsGaps.hXxs,
        Text(
          formatCount(total),
          style: (dense ? context.dsText.caption : context.dsText.labelStrong)
              .tint(onMedia ? DsColors.onMedia : colors.onSurface),
        ),
      ],
    );
  }
}

/// The heart that reacts: a tap for ❤️ (or to take back what she left), a
/// long press for the bar of reactions. Shows the glyph she chose.
///
/// [onReact] receives the chosen glyph, or null to clear her reaction.
class DsReactionButton extends StatelessWidget {
  const DsReactionButton({
    super.key,
    required this.reaction,
    required this.onReact,
    this.compact = false,
    this.color,
  });

  /// The glyph she left, or null for none.
  final String? reaction;
  final ValueChanged<String?> onReact;

  /// The small form under a comment.
  final bool compact;
  final Color? color;

  Future<void> _pick(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final chosen = await DsReactionPicker.show(
      context,
      anchor: anchor,
      current: reaction,
    );
    if (chosen == null) return;
    // Choosing the one she already has takes it back, as a tap does.
    onReact(chosen == reaction ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final current = reaction;
    final tint = color ?? colors.onSurfaceVariant;
    final label = current == null
        ? l10n.reactionLove
        : DsReactions.label(l10n, current);
    return Semantics(
      button: true,
      selected: current != null,
      label: label,
      hint: l10n.reactionPickerHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onReact(current == null ? DsReactions.like : null),
        onLongPress: () => _pick(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? DsSpacing.xxs : DsSpacing.xs,
            vertical: DsSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: DsMotion.fast,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: current == null
                    ? Icon(
                        Icons.favorite_border_rounded,
                        key: const ValueKey('none'),
                        size: compact ? DsSizes.iconXs : DsSizes.iconSm,
                        color: tint,
                      )
                    : Text(
                        current,
                        key: ValueKey(current),
                        style: TextStyle(
                          fontSize: compact ? 14 : 18,
                          height: 1.1,
                        ),
                        textScaler: TextScaler.noScaling,
                      ),
              ),
              if (!compact || current != null) ...[
                DsGaps.hXxs,
                Text(
                  label,
                  style: context.dsText.captionStrong.tint(
                    current == null ? tint : colors.favorite,
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

/// A reaction glyph drawn at an icon's size — emoji are text, and text sizes
/// belong to the design system rather than to each call site.
class DsReactionGlyph extends StatelessWidget {
  const DsReactionGlyph(this.emoji, {super.key, this.size = DsSizes.iconLg});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    emoji,
    style: TextStyle(fontSize: size * 0.92, height: 1.1),
    textScaler: TextScaler.noScaling,
  );
}
