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
import 'package:ohara/features/closet/presentation/providers/closet_finish_provider.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_compartments.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// The wardrobe's compartments, findable from a test.
ValueKey<String> closetBayKey(String compartment) =>
    ValueKey('closet-bay-$compartment'); // l10n-ignore: a widget key, not copy

/// The finish names, for the swatches and anything else that names one.
String closetFinishName(BuildContext context, ArmoireFinish finish) => switch (finish) {
  ArmoireFinish.white => context.l10n.closetFinishWhite,
  ArmoireFinish.oak => context.l10n.closetFinishOak,
  ArmoireFinish.walnut => context.l10n.closetFinishWalnut,
};

/// خزانتي, drawn as a modern fitted wardrobe.
///
/// Replaces the grid under a rail of filter chips. That layout asked her to
/// think like a database — pick a filter, scroll a list — about the one place
/// in her life she already knows by heart. Here she opens the drawer the
/// necklace is in.
///
/// Every compartment shows, shut or open, what is in it: dresses on wooden
/// hangers, folded pieces on the floor of their shelf, bags in their cubbies,
/// jewellery behind the glass of its drawer. Tapping it opens it; the "+" on
/// it adds a piece straight into it. The two cabinets along the top hold what
/// belongs to no single compartment: her favourites behind glass, and what
/// she has put away for another season.
class ClosetArmoire extends ConsumerWidget {
  const ClosetArmoire({super.key, required this.overview, this.gutter = DsSpacing.lg});

  final ClosetOverview overview;

  /// The page margin either side, for a caller already inside one.
  final double gutter;

  /// What the compartments show. One request for the whole front, grouped
  /// here by slot, rather than one per compartment: the previews are a
  /// glimpse, and the counts come from the overview, so a wardrobe larger
  /// than one page still counts right.
  static const previewQuery = ClosetItemQuery(limit: 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final finish = ref.watch(closetFinishProvider);
    final page = ref.watch(closetWardrobeProvider(previewQuery)).asData?.value;

    final bySlot = <String, List<ClosetItem>>{};
    for (final item in page?.items ?? const <ClosetItem>[]) {
      (bySlot[item.slot] ??= []).add(item);
    }
    final counts = {for (final entry in overview.slotCounts) entry.slot: entry.count};
    final favourites = [
      for (final item in page?.items ?? const <ClosetItem>[])
        if (item.isFavourite) item,
    ];
    // Favourites are not counted by the overview; they can be counted here
    // only when the preview holds the whole wardrobe.
    final favouritesCount = page == null || page.hasMore ? null : favourites.length;
    final rows = closetFloorPlan(overview.vocabulary);

    return ArmoireFinishScope(
      finish: finish,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inner = constraints.maxWidth - DsSpacing.xs * 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Summary(overview: overview, finish: finish),
                DsGaps.vSm,
                ArmoireCarcass(
                  child: Column(
                    children: [
                      _TopCabinets(
                        width: inner,
                        favourites: favourites,
                        favouritesCaption: favouritesCount != null && favouritesCount > 0
                            ? l10n.closetLookPieceCount(favouritesCount)
                            : l10n.closetDrawerFavouritesCaption,
                        stored: overview.archivedCount,
                        storedCaption: overview.archivedCount > 0
                            ? l10n.closetLookPieceCount(overview.archivedCount)
                            : l10n.closetDrawerStoredCaption,
                      ),
                      for (final row in rows) ...[
                        DsGaps.vXs,
                        _BayRow(
                          compartments: row,
                          width: inner,
                          vocabulary: overview.vocabulary,
                          counts: counts,
                          bySlot: bySlot,
                        ),
                      ],
                    ],
                  ),
                ),
                const ArmoirePlinth(),
                DsGaps.vXs,
                Text(
                  l10n.closetArmoireHint,
                  textAlign: TextAlign.center,
                  style: context.dsText.caption,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The line above the wardrobe: what it holds, and the finish swatches.
class _Summary extends ConsumerWidget {
  const _Summary({required this.overview, required this.finish});

  final ClosetOverview overview;
  final ArmoireFinish finish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.dsText;
    final palette = context.boutique;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.closetLookPieceCount(overview.itemsCount),
                style: text.sectionTitle.displayFamily.bold.tint(palette.ink),
              ),
              Text(
                l10n.closetArmoireOutfits(overview.seasonOutfitCapacity),
                style: text.caption,
              ),
            ],
          ),
        ),
        for (final option in ArmoireFinish.values)
          ArmoireFinishSwatch(
            finish: option,
            selected: option == finish,
            tooltip: l10n.closetFinishTooltip(closetFinishName(context, option)),
            onTap: () => ref.read(closetFinishProvider.notifier).choose(option),
          ),
      ],
    );
  }
}

// ── The top cabinets ──────────────────────────────────────────────────────

class _TopCabinets extends StatelessWidget {
  const _TopCabinets({
    required this.width,
    required this.favourites,
    required this.favouritesCaption,
    required this.stored,
    required this.storedCaption,
  });

  final double width;
  final List<ClosetItem> favourites;
  final String favouritesCaption;
  final int stored;
  final String storedCaption;

  @override
  Widget build(BuildContext context) {
    final height = DsSizes.thumbLg + MediaQuery.textScalerOf(context).scale(DsSpacing.lg);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _CabinetDoor(
              compartment: ClosetCompartment.favourites,
              caption: favouritesCaption,
              glass: true,
              hingeAtStart: true,
              inside: _ShelfOfThings(items: favourites),
            ),
          ),
          DsGaps.hXs,
          Expanded(
            child: _CabinetDoor(
              compartment: ClosetCompartment.stored,
              caption: storedCaption,
              hingeAtStart: false,
              inside: _StorageBoxes(count: stored),
            ),
          ),
        ],
      ),
    );
  }
}

class _CabinetDoor extends StatefulWidget {
  const _CabinetDoor({
    required this.compartment,
    required this.caption,
    required this.inside,
    required this.hingeAtStart,
    this.glass = false,
  });

  final ClosetCompartment compartment;
  final String caption;
  final Widget inside;
  final bool hingeAtStart;
  final bool glass;

  @override
  State<_CabinetDoor> createState() => _CabinetDoorState();
}

class _CabinetDoorState extends State<_CabinetDoor> with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: DsMotion.normal,
  );

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    unawaited(HapticFeedback.selectionClick());
    await _swing.forward();
    if (!mounted) return;
    await context.push(RoutePaths.closetCompartmentOf(widget.compartment.key));
    if (mounted) await _swing.reverse();
  }

  @override
  Widget build(BuildContext context) {
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
          animation: _swing,
          builder: (context, _) => ArmoireDoor(
            open: Curves.easeOutCubic.transform(_swing.value) * .55,
            glass: widget.glass,
            hingeAtStart: widget.hingeAtStart,
            inside: ArmoireCell(lit: _swing.value, seed: 29, child: widget.inside),
            child: ArmoireLabel(name: name, caption: widget.caption, stacked: true),
          ),
        ),
      ),
    );
  }
}

/// A few favourites standing on the floor of the glass cabinet.
class _ShelfOfThings extends StatelessWidget {
  const _ShelfOfThings({required this.items});

  final List<ClosetItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ArmoireCell.side + DsSpacing.xxs,
        ArmoireCell.ceiling + DsSpacing.xxs,
        ArmoireCell.side + DsSpacing.xxs,
        ArmoireCell.floor * .5,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.max(0.0, constraints.maxHeight);
          final fit = math.max(1, (constraints.maxWidth / (size * .8 + DsSpacing.xxs)).floor());
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final item in items.take(math.min(fit, 4)))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxxs),
                  child: _PieceCard(item: item, width: size * .74, height: size),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Fabric storage boxes on the cabinet floor — the season's put-away pieces.
class _StorageBoxes extends StatelessWidget {
  const _StorageBoxes({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final boxes = math.min(3, count);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ArmoireCell.side + DsSpacing.xxs,
        DsSpacing.lg,
        ArmoireCell.side + DsSpacing.xxs,
        ArmoireCell.floor * .5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < boxes; i++) ...[
            if (i > 0) DsGaps.hXxs,
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: DsRadius.borderXs,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(DsColors.warmBeige, a.wood, .3)!,
                      Color.lerp(DsColors.warmBeige, a.woodDeep, .55)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(color: a.shade, blurRadius: 3, offset: const Offset(1, 2)),
                  ],
                ),
                // The box's handle: a little leather loop.
                child: SizedBox(
                  height: double.infinity,
                  child: Align(
                    alignment: const Alignment(0, -.4),
                    child: Container(
                      width: DsSpacing.md,
                      height: DsSpacing.xxs,
                      decoration: BoxDecoration(
                        color: Color.lerp(a.woodDeep, a.shade, .5),
                        borderRadius: DsRadius.borderPill,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── The compartments ──────────────────────────────────────────────────────

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) DsGaps.hXs,
          SizedBox(
            width: bayWidth,
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

  /// Where the rod and the pegs sit: under the LED strip, below the "+".
  static const double fixturesTop = DsSizes.controlSm - DsSpacing.xxs;

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

  /// The drawer slides out, or the compartment light comes up — then it
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
    final knob = ArmoireAddKnob(tooltip: l10n.closetDrawerAddTo(widget.name), onPressed: _add);
    // A narrow compartment has room for the name and a number, not a phrase.
    final narrow = widget.width < DsSizes.railCardWidth * .8;
    final label = ArmoireLabel(
      name: widget.name,
      caption: narrow && widget.count > 0 ? '${widget.count}' : countLabel,
    );

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
            return widget.compartment.style == ClosetCompartmentStyle.drawer
                ? _drawer(t, label, knob)
                : _cavity(t, label, knob);
          },
        ),
      ),
    );
  }

  Widget _drawer(double t, Widget label, Widget knob) {
    // Jewellery is the one drawer worth seeing into while it is shut.
    final glass = widget.compartment.slot == 'JEWELRY';
    return ArmoireDrawer(
      pulled: t,
      handle: math.min(widget.width * .32, DsSizes.thumbMd),
      window: glass ? _VelvetTray(items: widget.items) : null,
      windowHeight: DsSizes.avatarLg,
      child: Row(
        children: [
          // A full-width drawer centres its name; a narrow one needs the
          // room more than the symmetry.
          if (widget.width > DsSizes.railCardWidth * 1.4)
            const SizedBox(width: DsSizes.controlSm),
          Expanded(child: label),
          knob,
        ],
      ),
    );
  }

  Widget _cavity(double t, Widget label, Widget knob) {
    final style = widget.compartment.style;
    final height = switch (style) {
      ClosetCompartmentStyle.rail => DsSizes.thumbLg + DsSizes.thumbSm,
      ClosetCompartmentStyle.rack => DsSizes.thumbLg + DsSizes.thumbSm,
      ClosetCompartmentStyle.hooks => DsSizes.thumbLg + DsSpacing.xl,
      _ => DsSizes.thumbLg,
    };
    final inside = switch (style) {
      _ when widget.compartment.slot == 'BAG' => _Cubbies(items: widget.items),
      ClosetCompartmentStyle.rail => _Hanging(
        items: widget.items,
        width: widget.width,
        height: height,
      ),
      ClosetCompartmentStyle.hooks => _OnPegs(
        items: widget.items,
        width: widget.width,
        height: height,
      ),
      ClosetCompartmentStyle.rack => _ShoeShelves(items: widget.items, height: height),
      _ => _OnTheFloor(items: widget.items),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.width,
          height: height,
          child: ArmoireCell(
            lit: t,
            seed: widget.compartment.key.hashCode & 0xff,
            child: Stack(
              children: [
                Positioned.fill(child: inside),
                PositionedDirectional(top: 0, end: 0, child: knob),
              ],
            ),
          ),
        ),
        // The board under it, with the compartment's name on its edge.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs + 1),
          child: label,
        ),
      ],
    );
  }
}

// ── What a compartment shows ──────────────────────────────────────────────

/// A piece's photograph, with the shadow it casts on the back wall.
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
        borderRadius: DsRadius.borderXs,
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .55),
            blurRadius: DsSpacing.xs,
            offset: const Offset(DsSpacing.xxxs, DsSpacing.xxs),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderXs,
        child: ClosetPhoto(
          url: item.imageUrl,
          slot: item.slot,
          blurHash: item.blurHash,
          iconSize: math.max(DsSizes.iconXxs, math.min(width, height) * .42),
        ),
      ),
    );
  }
}

/// Up to three pieces on wooden hangers along the rod, overlapping the way
/// clothes hang.
class _Hanging extends StatelessWidget {
  const _Hanging({required this.items, required this.width, required this.height});

  final List<ClosetItem> items;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    const rodTop = _Bay.fixturesTop;
    const rodHeight = DsSpacing.sm;
    const hangerHeight = DsSpacing.md + DsSpacing.xxs;
    const top = rodTop + rodHeight * .5 - DsSpacing.xxxs;
    final inner = width - ArmoireCell.side * 2;
    final cardHeight = height - top - hangerHeight - ArmoireCell.floor - DsSpacing.xxs;
    final cardWidth = math.min(inner * .56, cardHeight * .62);
    final shown = items.take(3).toList(growable: false);
    final step = shown.length < 2
        ? 0.0
        : math.min(cardWidth * .55, (inner - DsSpacing.xs - cardWidth) / (shown.length - 1));
    final group = cardWidth + step * math.max(0, shown.length - 1);
    final start = (width - group) / 2;

    return Stack(
      children: [
        const Positioned(
          top: rodTop,
          left: ArmoireCell.side,
          right: ArmoireCell.side,
          child: ArmoireRod(height: rodHeight),
        ),
        if (shown.isEmpty)
          // Bare hangers on the rod: the space is there, waiting.
          for (final dx in [-.16, .16])
            Positioned(
              top: top,
              left: width / 2 + width * dx - cardWidth * .4,
              child: ArmoireHanger(width: cardWidth * .8, height: hangerHeight),
            )
        else
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              top: top,
              start: start + step * i,
              child: Column(
                children: [
                  ArmoireHanger(width: cardWidth * .9, height: hangerHeight),
                  _PieceCard(item: shown[i], width: cardWidth, height: cardHeight),
                ],
              ),
            ),
      ],
    );
  }
}

/// Folded pieces standing on the compartment floor.
class _OnTheFloor extends StatelessWidget {
  const _OnTheFloor({required this.items});

  final List<ClosetItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ArmoireCell.side + DsSpacing.xxs,
        _Bay.fixturesTop,
        ArmoireCell.side + DsSpacing.xxs,
        ArmoireCell.floor * .45,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxHeight;
          final fit = math.max(1, (constraints.maxWidth / (size + DsSpacing.xxs)).floor());
          final shown = items.take(math.min(fit, 4)).toList(growable: false);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) DsGaps.hXxs,
                _PieceCard(item: shown[i], width: size, height: size * .86),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Bags, each in its own cubby between thin wooden dividers.
class _Cubbies extends StatelessWidget {
  const _Cubbies({required this.items});

  final List<ClosetItem> items;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ArmoireCell.side,
        ArmoireCell.ceiling,
        ArmoireCell.side,
        ArmoireCell.floor * .45,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0)
              Container(
                width: DsSpacing.xxs,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [a.panelLight, a.panelDeep]),
                  boxShadow: [
                    BoxShadow(color: a.shade, blurRadius: 3, offset: const Offset(1, 0)),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.xs,
                  _Bay.fixturesTop - ArmoireCell.ceiling,
                  DsSpacing.xs,
                  0,
                ),
                child: i < items.length
                    ? LayoutBuilder(
                        builder: (context, c) {
                          final s = math.min(c.maxWidth, c.maxHeight);
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: _PieceCard(item: items[i], width: s, height: s * .9),
                          );
                        },
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Accessories hanging from small hooks on the back wall.
class _OnPegs extends StatelessWidget {
  const _OnPegs({required this.items, required this.width, required this.height});

  final List<ClosetItem> items;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    const pegTop = _Bay.fixturesTop;
    const peg = DsSpacing.sm;
    const strap = DsSpacing.sm;
    final card = height - pegTop - peg / 2 - strap - ArmoireCell.floor - DsSpacing.xs;
    final inner = width - ArmoireCell.side * 2;
    final pegs = math.max(2, math.min(3, (inner / (card + DsSpacing.md)).floor()));
    final gap = inner / pegs;

    return Stack(
      children: [
        for (var i = 0; i < pegs; i++) ...[
          if (i < items.length) ...[
            Positioned(
              top: pegTop + peg / 2,
              left: ArmoireCell.side + gap * i + gap / 2 - card * .3,
              child: CustomPaint(
                size: Size(card * .6, strap),
                painter: _StrapPainter(color: Color.lerp(a.woodDeep, a.shade, .6)!),
              ),
            ),
            Positioned(
              top: pegTop + peg / 2 + strap - DsSpacing.xxxs,
              left: ArmoireCell.side + gap * i + gap / 2 - card / 2,
              child: _PieceCard(item: items[i], width: card, height: card),
            ),
          ],
          Positioned(
            top: pegTop,
            left: ArmoireCell.side + gap * i + gap / 2 - peg / 2,
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
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    final top = Offset(size.width / 2, 0);
    canvas.drawLine(top, Offset(0, size.height), paint);
    canvas.drawLine(top, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_StrapPainter old) => old.color != color;
}

/// Two slanted shoe shelves, each with its rail.
class _ShoeShelves extends StatelessWidget {
  const _ShoeShelves({required this.items, required this.height});

  final List<ClosetItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    const shelf = DsSpacing.md;
    const top = ArmoireCell.ceiling + DsSpacing.xs;
    final level = (height - top - ArmoireCell.floor - DsSpacing.xxs) / 2;
    final shoe = level - shelf;
    final upper = items.take(2).toList(growable: false);
    final lower = items.skip(2).take(2).toList(growable: false);

    Widget row(List<ClosetItem> pieces) => SizedBox(
      height: shoe,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < pieces.length; i++) ...[
            if (i > 0) DsGaps.hXs,
            Transform.rotate(
              angle: -.08,
              child: _PieceCard(item: pieces[i], width: shoe * 1.25, height: shoe * .8),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ArmoireCell.side,
        top,
        ArmoireCell.side,
        ArmoireCell.floor,
      ),
      child: Column(
        children: [
          row(upper),
          const ArmoireShelf(height: shelf, slant: true),
          DsGaps.vXxs,
          row(lower),
          const ArmoireShelf(height: shelf, slant: true),
        ],
      ),
    );
  }
}

/// What shows through the glass of the jewellery drawer: the velvet tray
/// and its pieces in their cushions.
class _VelvetTray extends StatelessWidget {
  const _VelvetTray({required this.items});

  final List<ClosetItem> items;

  @override
  Widget build(BuildContext context) {
    return ArmoireVelvet(
      radius: 0,
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xxs),
        child: Row(
          children: [
            for (var i = 0; i < 6; i++) ...[
              if (i > 0) DsGaps.hXxs,
              Expanded(
                child: ArmoireCushion(
                  child: i < items.length
                      ? Padding(
                          padding: const EdgeInsets.all(DsSpacing.xxs),
                          child: ClipOval(
                            child: ClosetPhoto(
                              url: items[i].imageUrl,
                              slot: items[i].slot,
                              iconSize: DsSizes.iconXs,
                            ),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
