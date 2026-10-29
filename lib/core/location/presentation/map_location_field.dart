import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/location/picked_place.dart';
import 'package:ohara/core/location/presentation/location_picker_screen.dart';
import 'package:ohara/core/location/presentation/map_pin.dart';
import 'package:ohara/core/location/presentation/map_tiles.dart';
import 'package:ohara/core/platform/app_haptics.dart';

/// The map, offered inside a form as the quick way through it.
///
/// Before a pin: an invitation that looks like a map. After: the real map,
/// small, with her pin on it and what it says underneath — tap it to move
/// the pin, or take the pin away and type instead.
class MapLocationField extends StatelessWidget {
  const MapLocationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.placeLabel,
    this.initialGovernorate,
  });

  final PickedPlace? value;

  /// Called with the new pin, or with null when she removes it.
  final ValueChanged<PickedPlace?> onChanged;

  final String? title;
  final String? subtitle;

  /// Passed to the picker's card — «موقع التوصيل», «موقع المحل».
  final String? placeLabel;

  /// Where the map opens when there is no pin yet.
  final String? initialGovernorate;

  Future<void> _open(BuildContext context) async {
    AppHaptics.light();
    final picked = await showLocationPicker(
      context,
      initialPoint: value?.point,
      initialGovernorate: initialGovernorate,
      placeLabel: placeLabel,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: DsMotion.slow,
      switchInCurve: DsMotion.gentle,
      switchOutCurve: DsMotion.standard,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: value == null
          ? _Invitation(
              key: const ValueKey('invite'),
              title: title ?? context.l10n.locationFieldTitle,
              subtitle: subtitle ?? context.l10n.locationFieldSubtitle,
              onTap: () => _open(context),
            )
          : _Preview(
              key: ValueKey(value!.coordinatesLabel),
              place: value!,
              onChange: () => _open(context),
              onRemove: () {
                AppHaptics.light();
                onChanged(null);
              },
            ),
    );
  }
}

/// A card dressed as a map: streets, a river, a few blocks, and a pin that
/// breathes — so it reads as «tap me for the map» before a word is read.
class _Invitation extends StatefulWidget {
  const _Invitation({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_Invitation> createState() => _InvitationState();
}

class _InvitationState extends State<_Invitation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _breathed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating && !_breathed) {
      // A few breaths to catch her eye, then still: a form that never stops
      // moving is tiring to fill in.
      _breathed = true;
      _breath
          .repeat(reverse: true, count: 6)
          .whenCompleteOrCancel(() {
            if (mounted) _breath.animateTo(0, duration: DsMotion.moderate);
          });
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DsScaleAnimations.tapScale(
      onTap: widget.onTap,
      pressedScale: DsMotion.pressedScale,
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderCard,
          border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
          boxShadow: context.glowShadow(colors.primary, blur: 22, alpha: 0.16),
        ),
        child: ClipRRect(
          borderRadius: DsRadius.borderCard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _MapSketchPainter(
                  land: isDark
                      ? colors.surfaceElevated
                      : Color.alphaBlend(
                          colors.primary.withValues(alpha: 0.05),
                          colors.surface,
                        ),
                  road: isDark
                      ? colors.outline.withValues(alpha: 0.35)
                      : Colors.white,
                  roadEdge: colors.primary.withValues(alpha: 0.12),
                  water: colors.info.withValues(alpha: isDark ? 0.25 : 0.16),
                  park: colors.success.withValues(alpha: isDark ? 0.18 : 0.12),
                  route: colors.primary.withValues(alpha: 0.55),
                  rtl: context.isRtl,
                ),
              ),
              // Fades the sketch behind the words so they stay legible.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [
                      (isDark ? colors.surfaceElevated : colors.surface)
                          .withValues(alpha: 0.97),
                      (isDark ? colors.surfaceElevated : colors.surface)
                          .withValues(alpha: 0.82),
                      (isDark ? colors.surfaceElevated : colors.surface)
                          .withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: DsSizes.avatarLg,
                      height: DsSizes.avatarLg,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: context.primaryGradient,
                        boxShadow: context.glowShadow(
                          colors.primary,
                          blur: 18,
                          alpha: 0.35,
                        ),
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        color: DsColors.onMedia,
                      ),
                    ),
                    DsGaps.hSm,
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.body.bold.tint(
                              colors.onSurface,
                            ),
                          ),
                          DsGaps.vXxxs,
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.caption.tint(
                              colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The breathing pin, on the sketch's side of the card.
                    SizedBox(
                      width: 56,
                      child: AnimatedBuilder(
                        animation: _breath,
                        builder: (context, child) {
                          final t = DsMotion.silk.transform(_breath.value);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.translate(
                                offset: Offset(0, -6 * t),
                                child: const MapPin(scale: 0.62),
                              ),
                              PinGroundShadow(lift: t),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapSketchPainter extends CustomPainter {
  _MapSketchPainter({
    required this.land,
    required this.road,
    required this.roadEdge,
    required this.water,
    required this.park,
    required this.route,
    required this.rtl,
  });

  final Color land;
  final Color road;
  final Color roadEdge;
  final Color water;
  final Color park;
  final Color route;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    // The sketch lives at the pin's end of the card.
    if (!rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final w = size.width;
    final h = size.height;

    // A park, a river and its bank.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.08, w * 0.16, h * 0.34),
        const Radius.circular(10),
      ),
      Paint()..color = park,
    );
    final river = Path()
      ..moveTo(0, h * 0.82)
      ..cubicTo(w * 0.15, h * 0.62, w * 0.28, h * 1.05, w * 0.48, h * 0.78)
      ..lineTo(w * 0.48, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(river, Paint()..color = water);

    // Streets: a wider avenue and a grid of lanes, each with a soft edge.
    void street(Offset a, Offset b, double width) {
      canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..color = roadEdge
            ..strokeWidth = width + 2
            ..strokeCap = StrokeCap.round,
        )
        ..drawLine(
          a,
          b,
          Paint()
            ..color = road
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round,
        );
    }

    street(Offset(w * 0.0, h * 0.55), Offset(w * 0.5, h * 0.42), 7);
    street(Offset(w * 0.24, 0), Offset(w * 0.3, h), 5);
    street(Offset(w * 0.1, 0), Offset(w * 0.14, h * 0.7), 3);
    street(Offset(w * 0.38, 0), Offset(w * 0.44, h), 3);
    street(Offset(0, h * 0.2), Offset(w * 0.5, h * 0.16), 3);

    // The way to her door, dashed, ending under the pin.
    final dash = Paint()
      ..color = route
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const segments = 9;
    final from = Offset(w * 0.02, h * 0.92);
    final to = Offset(w * 0.085, h * 0.62);
    for (var i = 0; i < segments; i += 2) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      canvas.drawLine(
        Offset.lerp(from, to, t0)!,
        Offset.lerp(from, to, math.min(1, t1))!,
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_MapSketchPainter old) =>
      old.land != land ||
      old.road != road ||
      old.water != water ||
      old.park != park ||
      old.route != route ||
      old.rtl != rtl;
}

/// The pin she dropped, on a small live map.
class _Preview extends StatelessWidget {
  const _Preview({
    super.key,
    required this.place,
    required this.onChange,
    required this.onRemove,
  });

  final PickedPlace place;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headline = place.headline.isEmpty
        ? l10n.mapPickerUnknownPlace
        : place.headline;

    return Container(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderCard,
        color: isDark ? colors.surfaceElevated : colors.surface,
        border: Border.all(color: colors.primary, width: 1.4),
        boxShadow: context.glowShadow(colors.primary, blur: 20, alpha: 0.18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 148,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: place.point,
                      initialZoom: 16.5,
                      backgroundColor: isDark
                          ? DsColors.surfaceDark
                          : DsColors.backgroundSecondary,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: MapTiles.layers(
                      context,
                      satellite: false,
                      dark: isDark,
                    ),
                  ),
                ),
                // The pin's tip on the centre of the map.
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, -MapPin.height * 0.8 / 2),
                    child: const MapPin(scale: 0.8),
                  ),
                ),
                const Center(child: PinGroundShadow(lift: 0)),
                PositionedDirectional(
                  top: DsSpacing.sm,
                  start: DsSpacing.sm,
                  child: _Badge(
                    icon: Icons.verified_rounded,
                    label: l10n.locationFieldPinned,
                  ),
                ),
                PositionedDirectional(
                  top: DsSpacing.xs,
                  end: DsSpacing.xs,
                  child: Material(
                    color: colors.surface.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: l10n.locationFieldRemove,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: DsSizes.iconSm,
                        color: colors.onSurface,
                      ),
                      onPressed: onRemove,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: onChange),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.sm,
              DsSpacing.xs,
              DsSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  place.isRural
                      ? Icons.landscape_rounded
                      : Icons.location_on_rounded,
                  color: colors.primary,
                  size: DsSizes.iconSm,
                ),
                DsGaps.hXs,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.semibold.tint(
                          colors.onSurface,
                        ),
                      ),
                      if (place.subtitle.isNotEmpty)
                        Text(
                          place.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption,
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onChange,
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                  label: Text(l10n.locationFieldChange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        gradient: context.primaryGradient,
        borderRadius: DsRadius.borderPill,
        boxShadow: context.shadowSoft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DsSizes.iconXxs + 1, color: DsColors.onMedia),
          DsGaps.hXxs,
          Text(
            label,
            style: context.dsText.caption.semibold.tint(DsColors.onMedia),
          ),
        ],
      ),
    );
  }
}

/// The «or type it» line between the map and the fields it replaces.
class MapOrTypeDivider extends StatelessWidget {
  const MapOrTypeDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
            child: Text(
              label ?? context.l10n.locationFieldOr,
              style: context.dsText.caption,
            ),
          ),
          Expanded(child: Divider(color: colors.divider)),
        ],
      ),
    );
  }
}
