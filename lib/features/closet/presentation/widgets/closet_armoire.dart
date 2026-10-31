import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_compartments.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// The wardrobe's compartments, findable from a test.
ValueKey<String> closetBayKey(String compartment) =>
    ValueKey('closet-bay-$compartment'); // l10n-ignore: a widget key, not copy

/// خزانتي, drawn as the wardrobe it is.
///
/// Replaces the grid under a rail of filter chips. That layout asked her to
/// think like a database — pick a filter, scroll a list — about the one place
/// in her life she already knows by heart. Here she opens the drawer the
/// necklace is in.
///
/// Every compartment shows, closed, what is in it: dresses on their hangers,
/// tops folded on the shelf, gems peeking from a drawer left a finger's width
/// open. Tapping it opens it; the brass "+" on it adds a piece straight into
/// it. The two boxes on top hold what is in no single compartment — her
/// favourites, and what she has put away for another season.
class ClosetArmoire extends ConsumerWidget {
  const ClosetArmoire({super.key, required this.overview, this.gutter = DsSpacing.lg});

  final ClosetOverview overview;

  /// The page margin either side, for a caller already inside one.
  final double gutter;

  /// What the closed compartments show. One request for the whole front,
  /// grouped here by slot, rather than one per compartment: the previews are
  /// a glimpse, and the counts on the plates come from the overview, so a
  /// wardrobe larger than one page still counts right.
  static const previewQuery = ClosetItemQuery(limit: 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final page = ref.watch(closetWardrobeProvider(previewQuery)).asData?.value;

    final bySlot = <String, List<ClosetItem>>{};
    for (final item in page?.items ?? const <ClosetItem>[]) {
      (bySlot[item.slot] ??= []).add(item);
    }
    final counts = {for (final entry in overview.slotCounts) entry.slot: entry.count};
    // Favourites are not counted by the overview; they can be counted here
    // only when the preview holds the whole wardrobe.
    final favourites = page == null || page.hasMore
        ? null
        : page.items.where((item) => item.isFavourite).length;

    final rows = closetFloorPlan(overview.vocabulary);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The body sits a little inside the cornice, like a real one.
          const bodyInset = DsSpacing.xxs;
          final inner = constraints.maxWidth - bodyInset * 2 - DsSpacing.sm * 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _TopBox(
                        compartment: ClosetCompartment.favourites,
                        rose: true,
                        caption: favourites != null && favourites > 0
                            ? l10n.closetLookPieceCount(favourites)
                            : l10n.closetDrawerFavouritesCaption,
                      ),
                    ),
                    const Spacer(flex: 2),
                    Expanded(
                      flex: 5,
                      child: _TopBox(
                        compartment: ClosetCompartment.stored,
                        caption: overview.archivedCount > 0
                            ? l10n.closetLookPieceCount(overview.archivedCount)
                            : l10n.closetDrawerStoredCaption,
                      ),
                    ),
                  ],
                ),
              ),
              ArmoireCrown(
                child: ArmoirePlaque(
                  large: true,
                  label: l10n.closetLookPieceCount(overview.itemsCount),
                  caption: l10n.closetArmoireOutfits(overview.seasonOutfitCapacity),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: bodyInset),
                child: ArmoireCarcass(
                  child: Column(
                    children: [
                      for (var r = 0; r < rows.length; r++) ...[
                        if (r > 0) DsGaps.vXs,
                        _BayRow(
                          compartments: rows[r],
                          width: inner,
                          vocabulary: overview.vocabulary,
                          counts: counts,
                          bySlot: bySlot,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const ArmoirePlinth(),
              DsGaps.vSm,
              Text(
                l10n.closetArmoireHint,
                textAlign: TextAlign.center,
                style: context.dsText.caption,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compartments that sit side by side.
class _BayRow extends StatelessWidget {
  const _BayRow({
    required this.compartments,
    required this.width,
    required this.vocabulary,
    required this.counts,
    required this.bySlot,
  });

  final List<ClosetCompartment> compartments;
  final double width;
  final ClosetVocabulary vocabulary;
  final Map<String, int> counts;
  final Map<String, List<ClosetItem>> bySlot;

  @override
  Widget build(BuildContext context) {
    final n = compartments.length;
    final bayWidth = (width - DsSpacing.xs * (n - 1)) / n;
    final isRail = compartments.first.style == ClosetCompartmentStyle.rail;

    final bays = <Widget>[
      for (var i = 0; i < n; i++) ...[
        if (i > 0) DsGaps.hXs,
        Expanded(
          child: _Bay(
            key: closetBayKey(compartments[i].key),
            compartment: compartments[i],
            name: compartments[i].name(context, vocabulary),
            count: counts[compartments[i].slot] ?? 0,
            items: bySlot[compartments[i].slot] ?? const [],
            width: bayWidth,
          ),
        ),
      ],
    ];

    final row = IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: bays),
    );
    if (!isRail) return row;

    // One rod runs the whole width of the hanging section, behind the
    // partitions, the way it does in a real wardrobe.
    return Stack(
      children: [
        row,
        const PositionedDirectional(
          top: _Bay.railTop,
          start: 0,
          end: 0,
          child: IgnorePointer(child: ArmoireRail(height: _Bay.railHeight)),
        ),
      ],
    );
  }
}

/// One compartment on the front of the wardrobe.
class _Bay extends StatefulWidget {
  const _Bay({
    super.key,
    required this.compartment,
    required this.name,
    required this.count,
    required this.items,
    required this.width,
  });

  final ClosetCompartment compartment;
  final String name;
  final int count;
  final List<ClosetItem> items;
  final double width;

  /// The band across the top of an open compartment where its "+" sits,
  /// clear of the rod and the pegs below it.
  static const double knobBand = DsSizes.controlSm - DsSpacing.xxs;
  static const double railTop = knobBand;
  static const double railHeight = DsSpacing.sm;

  @override
  State<_Bay> createState() => _BayState();
}

class _BayState extends State<_Bay> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: DsMotion.fast,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  /// The drawer slides out, or the compartment light comes on — then it
  /// opens. On the way back it closes again.
  Future<void> _open() async {
    unawaited(HapticFeedback.selectionClick());
    await _press.forward();
    if (!mounted) return;
    await context.push(RoutePaths.closetCompartmentOf(widget.compartment.key));
    if (mounted) await _press.reverse();
  }

  void _add() {
    final slot = widget.compartment.slot;
    if (slot == null) return;
    context.push(RoutePaths.closetAddItemTo(slot));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final countLabel = widget.count == 0
        ? l10n.closetDrawerEmpty
        : l10n.closetLookPieceCount(widget.count);
    final knob = ArmoireAddKnob(
      tooltip: l10n.closetDrawerAddTo(widget.name),
      onPressed: _add,
    );
    final plaque = ArmoirePlaque(label: widget.name, caption: countLabel);

    return Semantics(
      button: true,
      label: '${l10n.closetDrawerOpen(widget.name)}، $countLabel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_press.value);
            if (widget.compartment.style == ClosetCompartmentStyle.drawer) {
              return _drawer(t, plaque, knob);
            }
            return _cavity(t, plaque, knob);
          },
        ),
      ),
    );
  }

  Widget _drawer(double t, Widget plaque, Widget knob) {
    final peek = widget.items.isEmpty ? null : _GemPeek(items: widget.items);
    return ArmoireDrawerFront(
      pulled: t,
      peek: peek,
      peekHeight: DsSpacing.lg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSizes.controlSm,
              DsSpacing.xs,
              DsSizes.controlSm,
              DsSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: plaque),
                DsGaps.vXs,
                Center(
                  child: ArmoirePull(width: math.min(widget.width * .3, DsSizes.thumbSm)),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            child: Center(child: knob),
          ),
        ],
      ),
    );
  }

  Widget _cavity(double t, Widget plaque, Widget knob) {
    final style = widget.compartment.style;
    final previewHeight = _Bay.knobBand +
        switch (style) {
          ClosetCompartmentStyle.rail => DsSizes.thumbLg,
          ClosetCompartmentStyle.rack => DsSizes.thumbSm + DsSpacing.xxs,
          _ => DsSizes.thumbSm + DsSpacing.sm,
        };
    final preview = switch (style) {
      ClosetCompartmentStyle.rail => _RailPreview(
        items: widget.items,
        width: widget.width,
        height: previewHeight,
      ),
      ClosetCompartmentStyle.hooks => _HooksPreview(
        items: widget.items,
        width: widget.width,
        height: previewHeight,
      ),
      ClosetCompartmentStyle.rack => _ShelfPreview(
        items: widget.items,
        width: widget.width,
        height: previewHeight,
        slant: true,
      ),
      _ => _ShelfPreview(
        items: widget.items,
        width: widget.width,
        height: previewHeight,
      ),
    };

    return ArmoireRecess(
      lit: t,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: widget.width, height: previewHeight, child: preview),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.xxs,
                  DsSpacing.xxs,
                  DsSpacing.xxs,
                  DsSpacing.xs,
                ),
                child: plaque,
              ),
            ],
          ),
          // The "+" sits in the top corner — on the hanging section it reads
          // as the finial at the end of the rod.
          PositionedDirectional(top: 0, end: 0, child: knob),
        ],
      ),
    );
  }
}

// ── What a closed compartment shows ───────────────────────────────────────

/// A piece's photograph as a small framed card.
class _PieceCard extends StatelessWidget {
  const _PieceCard({required this.item, required this.width, required this.height});

  final ClosetItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: a.inlay.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .4),
            blurRadius: DsSpacing.xxs,
            offset: const Offset(0, DsSpacing.xxxs),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderSm,
        child: ClosetPhoto(
          url: item.imageUrl,
          slot: item.slot,
          blurHash: item.blurHash,
          iconSize: math.min(width, height) * .45,
        ),
      ),
    );
  }
}

/// Up to three pieces on hangers, overlapping along the rod.
class _RailPreview extends StatelessWidget {
  const _RailPreview({required this.items, required this.width, required this.height});

  final List<ClosetItem> items;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    const hangerHeight = DsSpacing.md;
    const top = _Bay.railTop + _Bay.railHeight * .5 - DsSpacing.xxxs;
    final cardHeight = height - top - hangerHeight - DsSpacing.xxs;
    final cardWidth = math.min(width * .48, cardHeight * .72);
    final shown = items.take(3).toList(growable: false);

    if (shown.isEmpty) {
      // Two bare hangers: the space is there, waiting.
      return Stack(
        children: [
          for (final dx in [-.18, .18])
            Positioned(
              top: top,
              left: width / 2 + width * dx - cardWidth * .35,
              child: Opacity(
                opacity: .55,
                child: ArmoireHanger(width: cardWidth * .7, height: hangerHeight),
              ),
            ),
        ],
      );
    }

    final step = shown.length == 1
        ? 0.0
        : math.min(cardWidth * .62, (width - DsSpacing.md - cardWidth) / (shown.length - 1));
    final groupWidth = cardWidth + step * (shown.length - 1);
    final start = (width - groupWidth) / 2;

    return Stack(
      children: [
        for (var i = 0; i < shown.length; i++)
          PositionedDirectional(
            top: top,
            start: start + step * i,
            child: Column(
              children: [
                ArmoireHanger(width: cardWidth * .78, height: hangerHeight),
                _PieceCard(item: shown[i], width: cardWidth, height: cardHeight),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pieces sitting on a shelf board — folded tops, or shoes on a slanted rack.
class _ShelfPreview extends StatelessWidget {
  const _ShelfPreview({
    required this.items,
    required this.width,
    required this.height,
    this.slant = false,
  });

  final List<ClosetItem> items;
  final double width;
  final double height;
  final bool slant;

  @override
  Widget build(BuildContext context) {
    const plank = DsSpacing.sm;
    final size = height - _Bay.knobBand - plank - DsSpacing.xxxs;
    final fit = math.max(1, ((width - DsSpacing.md) / (size + DsSpacing.xxs)).floor());
    final shown = items.take(math.min(fit, 5)).toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) DsGaps.hXxs,
                  Transform.rotate(
                    // Shoes lean on the rack; folded things sit square.
                    angle: slant ? -.06 : 0,
                    child: _PieceCard(
                      item: shown[i],
                      width: slant ? size * 1.1 : size,
                      height: slant ? size * .82 : size,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ArmoirePlank(height: plank, slant: slant),
      ],
    );
  }
}

/// Bags and scarves hanging from brass pegs by a strap.
class _HooksPreview extends StatelessWidget {
  const _HooksPreview({required this.items, required this.width, required this.height});

  final List<ClosetItem> items;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    const pegTop = _Bay.knobBand - DsSpacing.xs;
    const peg = DsSpacing.sm;
    final cardSize = height - pegTop - peg - DsSpacing.md;
    final pegs = math.max(2, math.min(3, (width / (cardSize + DsSpacing.md)).floor()));
    final gap = width / pegs;

    return Stack(
      children: [
        for (var i = 0; i < pegs; i++) ...[
          if (i < items.length) ...[
            // The strap, from the peg to the corners of the piece.
            Positioned(
              top: pegTop + peg / 2,
              left: gap * i + gap / 2 - cardSize * .32,
              child: CustomPaint(
                size: Size(cardSize * .64, DsSpacing.md),
                painter: _StrapPainter(color: a.brassDeep),
              ),
            ),
            Positioned(
              top: pegTop + peg / 2 + DsSpacing.md - DsSpacing.xxxs,
              left: gap * i + gap / 2 - cardSize / 2,
              child: _PieceCard(item: items[i], width: cardSize, height: cardSize),
            ),
          ],
          Positioned(
            top: pegTop,
            left: gap * i + gap / 2 - peg / 2,
            child: const ArmoirePeg(size: peg),
          ),
        ],
      ],
    );
  }
}

class _StrapPainter extends CustomPainter {
  const _StrapPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    final top = Offset(size.width / 2, 0);
    canvas.drawLine(top, Offset(0, size.height), paint);
    canvas.drawLine(top, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_StrapPainter old) => old.color != color;
}

/// What shows through the gap of a drawer left slightly open: the velvet, and
/// a few of the pieces on it, small as gems.
class _GemPeek extends StatelessWidget {
  const _GemPeek({required this.items});

  final List<ClosetItem> items;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    const size = DsSpacing.md;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items.take(5)) ...[
            Container(
              width: size,
              height: size,
              margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxxs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: a.brass, width: 1.2),
                boxShadow: [
                  BoxShadow(color: a.shade.withValues(alpha: .5), blurRadius: 2),
                ],
              ),
              child: ClipOval(
                child: ClosetPhoto(
                  url: item.imageUrl,
                  slot: item.slot,
                  iconSize: DsSizes.iconXxs * .75,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── The boxes on top ──────────────────────────────────────────────────────

class _TopBox extends StatefulWidget {
  const _TopBox({
    required this.compartment,
    required this.caption,
    this.rose = false,
  });

  final ClosetCompartment compartment;
  final String caption;
  final bool rose;

  @override
  State<_TopBox> createState() => _TopBoxState();
}

class _TopBoxState extends State<_TopBox> with SingleTickerProviderStateMixin {
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: DsMotion.fast,
  );

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    unawaited(HapticFeedback.selectionClick());
    await _lift.forward();
    if (!mounted) return;
    await context.push(RoutePaths.closetCompartmentOf(widget.compartment.key));
    if (mounted) await _lift.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final text = context.dsText;
    final name = widget.compartment.name(context);

    return Semantics(
      button: true,
      label: '${context.l10n.closetDrawerOpen(name)}، ${widget.caption}',
      excludeSemantics: true,
      child: GestureDetector(
        key: closetBayKey(widget.compartment.key),
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: AnimatedBuilder(
          animation: _lift,
          builder: (context, child) => ArmoireBox(
            rose: widget.rose,
            pressed: Curves.easeOut.transform(_lift.value),
            child: child!,
          ),
          child: Row(
            children: [
              Icon(
                widget.compartment.icon,
                size: DsSizes.iconXs,
                color: widget.rose ? context.dsColors.favorite : a.brassDeep,
              ),
              DsGaps.hXs,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.captionStrong.tint(a.ink),
                    ),
                    Text(
                      widget.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.micro.tint(a.muted),
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
