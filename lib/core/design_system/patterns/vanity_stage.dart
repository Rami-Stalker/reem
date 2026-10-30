import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/router/open_route.dart';

/// The shopper's private register: **her vanity table**.
///
/// The pages behind her profile — settings, language, appearance,
/// notifications, addresses, her sizes, her reviews — are not a shop window.
/// They are her own room, so they are drawn from the one piece of furniture
/// every woman's room shares, whatever she buys: the dressing table.
///
/// * [VanityAppBar] — the top of every such page: an arched mirror, ringed
///   with small lit bulbs, the room's pearl at its crown and its name under
///   it. It folds into a pearl bar as she scrolls.
/// * [VanityMirror] — that mirror on its own, for a portrait or a preview.
/// * [VanityTray] — a group of settings as a velvet jewellery tray, its name
///   on an engraved plaque.
/// * [VanityRow] — one thing in the tray: a pearl holding its icon, the name,
///   a line under it, and what it leads to.
/// * [PearlSwitch] — a switch whose thumb is a pearl.
/// * [VanityChoice] — one option of a few, as a compact mirror whose bulbs
///   light when it is the chosen one.
///
/// Everything resolves from [CustomerBoutiquePalette], so the vanity follows
/// dark mode with the rest of her pages.

// ---------------------------------------------------------------------------
// The mirror
// ---------------------------------------------------------------------------

/// An arched mirror ringed with small bulbs.
///
/// The glass holds a soft rose reflection; the frame is champagne; the bulbs
/// sit just outside the frame along the arch and the jambs. [lit] dims them
/// for a mirror that is not the chosen one.
class VanityMirror extends StatelessWidget {
  const VanityMirror({
    super.key,
    this.child,
    this.width = 120,
    this.lit = true,
    this.bulbs = 13,
  });

  final Widget? child;
  final double width;
  final bool lit;
  final int bulbs;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = width * 1.22;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MirrorPainter(
          lit: lit,
          bulbs: bulbs,
          glass: isDark ? DsColors.secondary900 : DsColors.primary50,
          blush: palette.primary,
          frame: palette.gold,
        ),
        child: child == null
            ? null
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  width * 0.115,
                  width * 0.115,
                  width * 0.115,
                  width * 0.055,
                ),
                child: ClipPath(clipper: const DsArchClipper(), child: child),
              ),
      ),
    );
  }
}

class _MirrorPainter extends CustomPainter {
  const _MirrorPainter({
    required this.lit,
    required this.bulbs,
    required this.glass,
    required this.blush,
    required this.frame,
  });

  final bool lit;
  final int bulbs;
  final Color glass;
  final Color blush;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.1;
    final glassRect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset * 0.4,
    );
    final arch = dsArchPath(glassRect);

    // The glass: a rose reflection rising from the bottom, and a slant of
    // light across it.
    canvas.drawPath(
      arch,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, 0.7),
          radius: 1.1,
          colors: [blush.withValues(alpha: 0.32), glass],
        ).createShader(glassRect),
    );
    canvas.save();
    canvas.clipPath(arch);
    final sheen = Path()
      ..moveTo(glassRect.left + glassRect.width * 0.15, glassRect.bottom)
      ..lineTo(glassRect.left + glassRect.width * 0.38, glassRect.bottom)
      ..lineTo(glassRect.right, glassRect.top + glassRect.height * 0.25)
      ..lineTo(glassRect.right, glassRect.top + glassRect.height * 0.05)
      ..close();
    canvas.drawPath(
      sheen,
      Paint()..color = DsColors.onMedia.withValues(alpha: 0.12),
    );
    canvas.restore();

    // The frame.
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035
        ..color = frame,
    );

    // The bulbs, spaced evenly along the frame, just outside it.
    final metrics = dsArchPath(
      glassRect.inflate(size.width * 0.06),
    ).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    // Along the arch and the jambs only, not the base.
    final span = metric.length * 0.78;
    final start = metric.length * 0.11;
    final r = size.width * 0.032;
    for (var i = 0; i < bulbs; i++) {
      final t = start + span * i / (bulbs - 1);
      final tangent = metric.getTangentForOffset(t);
      if (tangent == null) continue;
      final c = tangent.position;
      // None along the base: the mirror stands on it.
      if (c.dy > glassRect.bottom - glassRect.height * 0.08) continue;
      if (lit) {
        canvas.drawCircle(
          c,
          r * 2.4,
          Paint()
            ..shader = RadialGradient(
              colors: [
                DsColors.gold300.withValues(alpha: 0.6),
                DsColors.gold300.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: r * 2.4)),
        );
        canvas.drawCircle(c, r, Paint()..color = DsColors.gold100);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.5
            ..color = DsColors.gold400,
        );
      } else {
        canvas.drawCircle(c, r, Paint()..color = frame.withValues(alpha: 0.3));
      }
    }
  }

  @override
  bool shouldRepaint(_MirrorPainter old) =>
      old.lit != lit ||
      old.bulbs != bulbs ||
      old.glass != glass ||
      old.blush != blush ||
      old.frame != frame;
}

/// A pearl: a lustrous bead holding an icon — the room's mark on the mirror,
/// and the leading mark of every [VanityRow].
class VanityPearl extends StatelessWidget {
  const VanityPearl({
    super.key,
    required this.icon,
    this.size = DsSizes.controlMd,
    this.color,
  });

  final IconData icon;
  final double size;

  /// The tint of the pearl — the shop's rose by default, a status colour for
  /// a row that needs one.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final tint = color ?? palette.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [
            Color.lerp(palette.surface, DsColors.onMedia, 0.6)!,
            Color.lerp(palette.surface, tint, 0.18)!,
            Color.lerp(palette.surface, tint, 0.32)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.46, color: tint),
    );
  }
}

// ---------------------------------------------------------------------------
// The header
// ---------------------------------------------------------------------------

/// The top of every page behind her profile: the vanity mirror.
///
/// Open, it is her mirror at the head of the page — bulbs lit round the arch,
/// the room's pearl in the glass, and the room's name under it in the display
/// serif. As she scrolls it folds into a pearl bar with the name alone.
///
/// The same arguments as [PremiumAppBar] for the common case, so a page
/// moves across by changing one name.
class VanityAppBar extends StatelessWidget {
  const VanityAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.reflection,
    this.collapsedTitle,
    this.showBack = false,
    this.onBack,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// What the mirror shows instead of the room's pearl — her portrait, on
  /// the page that is about her.
  final Widget? reflection;

  /// The name in the folded bar, when it is not [title] — the hub's mirror
  /// shows her name, its bar says «الإعدادات».
  final String? collapsedTitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  static const double _mirror = 104;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final body =
        _mirror * 1.22 +
        _ledge +
        DsSpacing.sm +
        40 +
        (subtitle == null ? 0 : 42) +
        DsSpacing.lg;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: DsSizes.appBarHeight + body,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: palette.ink),
      actionsIconTheme: IconThemeData(color: palette.ink),
      leading: showBack
          ? IconButton(
              icon: Icon(
                DsIcons.back,
                color: palette.ink,
                size: DsSizes.iconSm,
              ),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => popOrHome(context),
            )
          : null,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = MediaQuery.paddingOf(context).top;
          final collapsed = DsSizes.appBarHeight + top;
          final expanded = DsSizes.appBarHeight + body + top;
          final t =
              ((constraints.maxHeight - collapsed) / (expanded - collapsed))
                  .clamp(0.0, 1.0);
          return _VanityHeader(
            openness: t,
            title: title,
            barTitle: collapsedTitle ?? title,
            subtitle: subtitle,
            icon: icon,
            reflection: reflection,
            topInset: top,
          );
        },
      ),
    );
  }
}

const double _ledge = 10;

/// The header's mirror standing on the table: a warm halo of light behind
/// it, and a champagne ledge under its base.
class _MirrorOnLedge extends StatelessWidget {
  const _MirrorOnLedge({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    const width = VanityAppBar._mirror;
    return SizedBox(
      width: width * 3,
      height: width * 1.22 + _ledge,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // The light the bulbs throw on the wall.
          Positioned(
            top: -width * 0.35,
            child: IgnorePointer(
              child: Container(
                width: width * 2.6,
                height: width * 1.9,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      palette.gold.withValues(alpha: 0.22),
                      palette.primary.withValues(alpha: 0.06),
                      palette.primary.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          VanityMirror(width: width, child: child),
          // The table's edge.
          Positioned(
            bottom: 0,
            child: Container(
              width: width * 2.4,
              height: _ledge - 3,
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderPill,
                gradient: LinearGradient(
                  colors: [
                    palette.gold.withValues(alpha: 0),
                    palette.gold,
                    palette.gold.withValues(alpha: 0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.gold.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanityHeader extends StatelessWidget {
  const _VanityHeader({
    required this.openness,
    required this.title,
    required this.barTitle,
    required this.subtitle,
    required this.icon,
    required this.reflection,
    required this.topInset,
  });

  final Widget? reflection;
  final String barTitle;

  final double openness;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final barOpacity = (1 - openness * 2.4).clamp(0.0, 1.0);
    final openOpacity = ((openness - 0.3) / 0.7).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // The wall behind the mirror: the page's own ground, deepening to a
        // pearl bar as it folds.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(
                  palette.surface,
                  palette.background,
                  openness,
                )!.withValues(alpha: 0.96),
                palette.background.withValues(alpha: 0.6 * (1 - openness)),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: palette.line.withValues(alpha: 1 - openness),
              ),
            ),
          ),
        ),
        if (barOpacity > 0)
          Positioned(
            top: topInset,
            left: DsSizes.appBarHeight,
            right: DsSizes.appBarHeight,
            height: DsSizes.appBarHeight,
            child: Opacity(
              opacity: barOpacity,
              child: Center(
                child: Text(
                  barTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.sectionTitle.displayFamily.bold.tint(
                    palette.ink,
                  ),
                ),
              ),
            ),
          ),
        if (openOpacity > 0)
          Positioned(
            left: DsSpacing.lg,
            right: DsSpacing.lg,
            bottom: DsSpacing.lg,
            child: IgnorePointer(
              ignoring: openness < 0.5,
              child: Opacity(
                opacity: openOpacity,
                child: Transform.translate(
                  offset: Offset(0, (1 - openness) * DsSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MirrorOnLedge(
                        child:
                            reflection ??
                            (icon == null
                                ? null
                                : Center(
                                    child: VanityPearl(
                                      icon: icon!,
                                      size: DsSizes.controlLg,
                                    ),
                                  )),
                      ),
                      DsGaps.vSm,
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.dsText.pageTitle.displayFamily.bold.tint(
                          palette.ink,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.dsText.body.tint(palette.muted),
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

// ---------------------------------------------------------------------------
// The tray
// ---------------------------------------------------------------------------

/// A group of settings as a velvet jewellery tray: a soft panel with an inner
/// champagne frame, its name on a small engraved plaque at the top.
class VanityTray extends StatelessWidget {
  const VanityTray({
    super.key,
    required this.children,
    this.title,
    this.padding = const EdgeInsets.symmetric(vertical: DsSpacing.xs),
  });

  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final tray = Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: palette.line),
        boxShadow: [
          for (final shadow in palette.shadow)
            BoxShadow(
              color: shadow.color.withValues(alpha: shadow.color.a * 0.6),
              blurRadius: shadow.blurRadius,
              offset: shadow.offset * 0.5,
            ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(DsSpacing.xxs),
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderXl,
          border: Border.all(color: palette.gold.withValues(alpha: 0.28)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.primarySoft.withValues(alpha: 0.35),
              palette.surface.withValues(alpha: 0),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  child: Divider(
                    height: DsSizes.dividerThickness,
                    color: palette.line,
                  ),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );

    if (title == null) return tray;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: VanityPlaque(label: title!)),
        DsGaps.vSm,
        tray,
      ],
    );
  }
}

/// An engraved plaque: a group's name, small, in a champagne-edged pill with
/// a tiny diamond at each end.
class VanityPlaque extends StatelessWidget {
  const VanityPlaque({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    Widget diamond() => Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: DsSpacing.xs - DsSpacing.xxxs,
        height: DsSpacing.xs - DsSpacing.xxxs,
        color: palette.gold,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        diamond(),
        DsGaps.hXs,
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md,
            vertical: DsSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: palette.goldSoft.withValues(alpha: 0.6),
            borderRadius: DsRadius.borderPill,
            border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: context.dsText.labelStrong.tint(palette.ink),
          ),
        ),
        DsGaps.hXs,
        diamond(),
      ],
    );
  }
}

/// One thing in a [VanityTray].
class VanityRow extends StatelessWidget {
  const VanityRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    this.tintTitle = true,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// A value, a switch, a badge. When null and [onTap] is set, a gold
  /// chevron says the row leads somewhere.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// The pearl's tint and the title's colour — for a row like «تسجيل الخروج»
  /// that is not like the others.
  final Color? color;

  /// Whether [color] reaches the title too, or only the pearl — a status
  /// (trusted, needs attention) marks the pearl; an action like signing out
  /// colours its name.
  final bool tintTitle;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          VanityPearl(icon: icon, color: color, size: DsSizes.controlSm + 4),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.dsText.bodyStrong.tint(
                    (tintTitle ? color : null) ?? palette.ink,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  DsGaps.vXxxs,
                  Text(
                    subtitle!,
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            DsGaps.hSm,
            trailing!,
          ] else if (onTap != null && showChevron)
            Icon(
              Icons.chevron_right_rounded,
              size: DsSizes.iconSm,
              color: palette.gold,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: DsRadius.borderXl, onTap: onTap, child: row),
    );
  }
}

// ---------------------------------------------------------------------------
// The pearl switch
// ---------------------------------------------------------------------------

/// A switch whose thumb is a pearl: champagne track when on, a soft blush
/// one when off.
class PearlSwitch extends StatelessWidget {
  const PearlSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const double _width = 52;
  static const double _height = 30;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final enabled = onChanged != null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final onSide = rtl ? Alignment.centerLeft : Alignment.centerRight;
    final offSide = rtl ? Alignment.centerRight : Alignment.centerLeft;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: DsReducedMotion.duration(DsMotion.normal),
            curve: DsMotion.gentle,
            width: _width,
            height: _height,
            padding: const EdgeInsets.all(DsSpacing.xxxs + 1),
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderPill,
              gradient: value
                  ? const LinearGradient(
                      colors: [DsColors.gold300, DsColors.gold500],
                    )
                  : null,
              color: value ? null : palette.primarySoft,
              border: Border.all(
                color: value ? DsColors.gold400 : palette.line,
              ),
            ),
            child: AnimatedAlign(
              duration: DsReducedMotion.duration(DsMotion.normal),
              curve: DsMotion.gentle,
              alignment: value ? onSide : offSide,
              child: Container(
                width: _height - 6,
                height: _height - 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.4),
                    colors: [
                      DsColors.onMedia,
                      DsColors.primary50,
                      DsColors.neutral200,
                    ],
                    stops: [0, 0.6, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DsColors.mediaScrim.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The choice
// ---------------------------------------------------------------------------

/// One option of a few, as a compact mirror.
///
/// The selected one stands lit — its bulbs glowing, its frame champagne, a
/// soft glow under it — and the rest stand quiet. [preview] fills the glass
/// (a sample of the theme, a script); otherwise the [icon] does.
class VanityChoice extends StatelessWidget {
  const VanityChoice({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.preview,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      excludeSemantics: true,
      child: DsScaleAnimations.tapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DsReducedMotion.duration(DsMotion.normal),
          curve: DsMotion.gentle,
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.sm,
            DsSpacing.md,
            DsSpacing.sm,
            DsSpacing.md,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: DsRadius.borderXxl,
            border: Border.all(
              color: selected ? palette.gold : palette.line,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.gold.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VanityMirror(
                width: 76,
                lit: selected,
                bulbs: 9,
                child:
                    preview ??
                    (icon == null
                        ? null
                        : Center(
                            child: Icon(
                              icon,
                              color: selected ? palette.primary : palette.muted,
                              size: DsSizes.iconMd,
                            ),
                          )),
              ),
              DsGaps.vSm,
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.dsText.bodyStrong.tint(
                  selected ? palette.ink : palette.muted,
                ),
              ),
              if (subtitle != null) ...[
                DsGaps.vXxxs,
                Text(
                  subtitle!,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The side margin of her pages: a phone's gutter below 600dp, wider above.
double vanityGutter(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? DsSpacing.lg : DsSpacing.xxl;

// ---------------------------------------------------------------------------
// The drawers
// ---------------------------------------------------------------------------

/// One drawer of the vanity: a place she opens often.
@immutable
class VanityDrawerItem {
  const VanityDrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The vanity's row of drawers: the few places she opens most, side by side
/// under the mirror, each a drawer front with a pearl knob.
class VanityDrawers extends StatelessWidget {
  const VanityDrawers({super.key, required this.items});

  final List<VanityDrawerItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.xs),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: palette.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) DsGaps.hXs,
            Expanded(child: _Drawer(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _Drawer extends StatelessWidget {
  const _Drawer({required this.item});

  final VanityDrawerItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: DsScaleAnimations.tapScale(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.xxs,
            DsSpacing.sm,
            DsSpacing.xxs,
            DsSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderXl,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.primarySoft, palette.raised],
            ),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The knob.
              Container(
                width: DsSpacing.md,
                height: DsSpacing.xs,
                decoration: BoxDecoration(
                  borderRadius: DsRadius.borderPill,
                  gradient: const LinearGradient(
                    colors: [DsColors.gold200, DsColors.gold400],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.gold.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              DsGaps.vSm,
              Icon(item.icon, color: palette.primary, size: DsSizes.iconMd),
              DsGaps.vXs,
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.dsText.caption.semibold.tint(palette.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The tape
// ---------------------------------------------------------------------------

/// A whole number on a ribbon tape measure: she slides the ribbon under a
/// gold needle, and the number above it follows in the display serif.
///
/// [value] may be null — nothing given yet. The ribbon then rests on the
/// middle of the range and the figure shows a dash until she moves it; the
/// [clearLabel] button takes a value back to nothing.
class VanityTape extends StatefulWidget {
  const VanityTape({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.unit,
    this.hint,
    this.clearLabel,
  });

  final int? value;
  final int min;
  final int max;
  final ValueChanged<int?> onChanged;
  final String unit;
  final String? hint;
  final String? clearLabel;

  @override
  State<VanityTape> createState() => _VanityTapeState();
}

class _VanityTapeState extends State<VanityTape> {
  static const double _step = 12;
  static const double _height = 64;

  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsetOf(widget.value ?? _middle),
  );

  /// Whether she is the one moving the ribbon — a snap or a jump from code
  /// must not give a value she never chose.
  bool _byHand = false;

  int get _middle => ((widget.min + widget.max) / 2).round();

  double _offsetOf(int value) => (value - widget.min) * _step;

  int _valueAt(double offset) =>
      (widget.min + (offset / _step).round()).clamp(widget.min, widget.max);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpBy(int delta) {
    final next = ((widget.value ?? _middle) + delta).clamp(
      widget.min,
      widget.max,
    );
    widget.onChanged(next);
    _controller.animateTo(
      _offsetOf(next),
      duration: DsReducedMotion.duration(DsMotion.fast),
      curve: DsMotion.gentle,
    );
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) _byHand = true;
    if (n is ScrollUpdateNotification && _byHand) {
      final v = _valueAt(n.metrics.pixels);
      if (v != widget.value) {
        HapticFeedback.selectionClick();
        widget.onChanged(v);
      }
    }
    if (n is ScrollEndNotification && _byHand) {
      _byHand = false;
      final target = _offsetOf(_valueAt(n.metrics.pixels));
      if ((target - n.metrics.pixels).abs() > 0.5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.hasClients) {
            _controller.animateTo(
              target,
              duration: DsReducedMotion.duration(DsMotion.fast),
              curve: DsMotion.gentle,
            );
          }
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final value = widget.value;
    return Semantics(
      slider: true,
      value: value == null ? '' : '$value ${widget.unit}',
      increasedValue:
          '${((value ?? _middle) + 1).clamp(widget.min, widget.max)}',
      decreasedValue:
          '${((value ?? _middle) - 1).clamp(widget.min, widget.max)}',
      onIncrease: () => _jumpBy(1),
      onDecrease: () => _jumpBy(-1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The figure.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                // l10n-ignore: a dash for "not given yet", not a word.
                value == null ? '—' : '$value',
                style: context.dsText.hero.displayFamily.bold.tint(
                  value == null ? palette.muted : palette.ink,
                ),
              ),
              DsGaps.hXs,
              Text(
                widget.unit,
                style: context.dsText.bodyStrong.tint(palette.gold),
              ),
            ],
          ),
          if (value == null && widget.hint != null)
            Text(
              widget.hint!,
              style: context.dsText.caption.tint(palette.muted),
            ),
          DsGaps.vSm,
          // The ribbon. A tape measure reads left to right in every language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: _height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth / 2 - _step / 2;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [palette.goldSoft, palette.surface],
                            ),
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: palette.gold.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: ListView.builder(
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: side),
                          itemExtent: _step,
                          itemCount: widget.max - widget.min + 1,
                          itemBuilder: (context, i) =>
                              _Tick(value: widget.min + i),
                        ),
                      ),
                      // The fade at both ends of the ribbon.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  palette.surface,
                                  palette.surface.withValues(alpha: 0),
                                  palette.surface.withValues(alpha: 0),
                                  palette.surface,
                                ],
                                stops: const [0, 0.18, 0.82, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // The needle, with a pearl at its head.
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: constraints.maxWidth / 2 - 7,
                        child: IgnorePointer(
                          child: Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    center: Alignment(-0.35, -0.4),
                                    colors: [
                                      DsColors.gold100,
                                      DsColors.gold400,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.gold.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Container(width: 2, color: palette.gold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (value != null && widget.clearLabel != null)
            TextButton(
              onPressed: () => widget.onChanged(null),
              child: Text(
                widget.clearLabel!,
                style: context.dsText.caption.semibold.tint(palette.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final ten = value % 10 == 0;
    final five = value % 5 == 0;
    return OverflowBox(
      maxWidth: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (ten)
            Text(
              '$value',
              style: context.dsText.caption.semibold.tint(palette.muted),
            ),
          DsGaps.vXxxs,
          Container(
            width: ten ? 2 : 1,
            height: ten ? 22 : (five ? 16 : 10),
            color: ten
                ? palette.gold
                : palette.muted.withValues(alpha: five ? 0.6 : 0.35),
          ),
        ],
      ),
    );
  }
}
