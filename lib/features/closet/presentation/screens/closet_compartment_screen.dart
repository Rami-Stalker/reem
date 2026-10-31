import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/open_route.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_compartments.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_item_tile.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_wear_feedback.dart';

/// How a compartment's pieces are ordered. Applied to the pieces loaded so
/// far.
enum ClosetSort { recent, mostWorn, leastWorn }

/// One compartment of the wardrobe, opened.
///
/// The page is the inside of the thing she opened, drawn the way that thing
/// keeps clothes: a rod of hangers, shelves of folded pieces, pegs, a
/// velvet-lined drawer, a shoe rack, a storage box. The drawer front she
/// pulled becomes the header, its name plate on it. The "+" at the bottom
/// files a new piece straight into this compartment.
///
/// Search, favourites and the order are in the header, as icons: the
/// compartment is already the filter that matters, so the page does not open
/// on a second rail of chips.
class ClosetCompartmentScreen extends ConsumerStatefulWidget {
  const ClosetCompartmentScreen({
    super.key,
    required this.compartmentKey,
    this.startWithSearch = false,
  });

  final String compartmentKey;

  /// Opened from the wardrobe's search button: the field is open and focused.
  final bool startWithSearch;

  @override
  ConsumerState<ClosetCompartmentScreen> createState() =>
      _ClosetCompartmentScreenState();
}

class _ClosetCompartmentScreenState extends ConsumerState<ClosetCompartmentScreen> {
  late final ClosetCompartment _compartment = ClosetCompartment.fromKey(
    widget.compartmentKey,
  );
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  late bool _searching = widget.startWithSearch;
  String _query = '';
  bool _favouritesOnly = false;
  ClosetSort _sort = ClosetSort.recent;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  ClosetItemQuery get _itemQuery =>
      _compartment.query(search: _query, favouritesOnly: _favouritesOnly);

  bool get _filtering => _query.isNotEmpty || _favouritesOnly;

  void _onSearch(String value) {
    _debounce?.cancel();
    // A request per keystroke would be a request per letter of "فستان".
    _debounce = Timer(DsMotion.moderate, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _searchFocus.requestFocus();
    } else {
      _debounce?.cancel();
      _search.clear();
      _searchFocus.unfocus();
      setState(() => _query = '');
    }
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _favouritesOnly = false;
    });
  }

  void _add() {
    final slot = _compartment.slot;
    context.push(
      slot == null ? RoutePaths.closetAddItem : RoutePaths.closetAddItemTo(slot),
    );
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(closetOverviewProvider)
      ..invalidate(closetWardrobeProvider(_itemQuery));
    try {
      await ref.read(closetWardrobeProvider(_itemQuery).future);
    } catch (_) {
      // The page draws its own error state; the spinner only needs to stop.
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final l10n = context.l10n;
    final overview = ref.watch(closetOverviewProvider).asData?.value;
    final wardrobeAsync = ref.watch(closetWardrobeProvider(_itemQuery));
    final name = _compartment.name(context, overview?.vocabulary);
    final count = _count(overview, wardrobeAsync.asData?.value);

    return Scaffold(
      backgroundColor: a.cavityDeep,
      // An empty compartment carries its own "add the first piece" in the
      // middle of the page; a second button under it would be noise.
      bottomNavigationBar:
          _compartment.acceptsNew &&
              (_filtering || wardrobeAsync.asData?.value.items.isNotEmpty == true)
          ? _AddBar(
              label: _compartment.isSlot
                  ? l10n.closetDrawerAddTo(name)
                  : l10n.closetAddPiece,
              onPressed: _add,
            )
          : null,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [a.cavity, a.cavityDeep],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              _DrawerHeader(
                name: name,
                caption: count == null
                    ? null
                    : count == 0
                    ? l10n.closetDrawerEmpty
                    : l10n.closetLookPieceCount(count),
                icon: _compartment.icon,
                actions: [
                  IconButton(
                    tooltip: l10n.closetSearchWardrobe,
                    isSelected: _searching,
                    onPressed: _toggleSearch,
                    icon: Icon(_searching ? Icons.search_off_rounded : Icons.search_rounded),
                  ),
                  if (!_compartment.isFavourites)
                    IconButton(
                      tooltip: _favouritesOnly
                          ? l10n.closetFavouritesOnlyOff
                          : l10n.closetFavouritesOnlyOn,
                      isSelected: _favouritesOnly,
                      onPressed: () => setState(() => _favouritesOnly = !_favouritesOnly),
                      icon: Icon(
                        _favouritesOnly
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _favouritesOnly ? context.dsColors.favorite : null,
                      ),
                    ),
                  _SortButton(
                    sort: _sort,
                    onSort: (value) => setState(() => _sort = value),
                  ),
                ],
              ),
              if (_searching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpacing.md,
                      DsSpacing.md,
                      DsSpacing.md,
                      0,
                    ),
                    child: DsInputField.search(
                      controller: _search,
                      focusNode: _searchFocus,
                      autofocus: widget.startWithSearch,
                      hint: l10n.closetSearchHint,
                      onChanged: _onSearch,
                      onClear: () {
                        _debounce?.cancel();
                        setState(() => _query = '');
                      },
                    ),
                  ),
                ),
              ...wardrobeAsync.when(
                loading: () => [_InteriorSkeleton(style: _compartment.style)],
                error: (_, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: DsErrorState(
                      message: l10n.closetItemsFailed,
                      onRetry: () => ref.invalidate(closetWardrobeProvider(_itemQuery)),
                    ),
                  ),
                ],
                data: (page) => _interior(context, page),
              ),
              DsGaps.sliverXl,
            ],
          ),
        ),
      ),
    );
  }

  /// How many pieces the plate says it holds. The overview's number when it
  /// has one, because the loaded page may be only the first of several.
  int? _count(ClosetOverview? overview, ClosetItemPage? page) {
    if (_filtering) return page?.items.length;
    if (overview != null) {
      if (_compartment.isStored) return overview.archivedCount;
      if (_compartment.key == ClosetCompartment.allKey) return overview.itemsCount;
      final slot = _compartment.slot;
      if (slot != null) {
        for (final entry in overview.slotCounts) {
          if (entry.slot == slot) return entry.count;
        }
        return page == null ? null : (page.hasMore ? null : page.items.length);
      }
    }
    if (page == null || page.hasMore) return null;
    return page.items.length;
  }

  List<Widget> _interior(BuildContext context, ClosetItemPage page) {
    if (page.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyInterior(
            compartment: _compartment,
            filtering: _filtering,
            onClear: _clearFilters,
            onAdd: _compartment.acceptsNew ? _add : null,
          ),
        ),
      ];
    }

    final items = _sorted(page.items);
    final style = _compartment.style;
    final columns = _columnsFor(style);
    final rows = (items.length / columns).ceil();
    final notifier = ref.read(closetWardrobeProvider(_itemQuery).notifier);

    final list = SliverList.builder(
      itemCount: rows,
      itemBuilder: (context, r) {
        // Reaching the last rows asks for the next page, so a long
        // compartment scrolls as one rather than ending in a button.
        if (page.hasMore && r >= rows - 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) => notifier.loadMore());
        }
        final row = items.skip(r * columns).take(columns).toList(growable: false);
        return DsStaggerAnimations.item(
          index: r,
          child: _InteriorRow(
            style: style,
            columns: columns,
            items: row,
            tile: (item, dense) => ClosetItemTile(
              item: item,
              dense: dense,
              showWear: item.status == ClosetItemStatus.active,
              onTap: () => context.push(RoutePaths.closetItemOf(item.id)),
              onWear: () => logClosetWear(context, ref, item, onChanged: notifier.replace),
            ),
          ),
        );
      },
    );

    final lined = style == ClosetCompartmentStyle.drawer || style == ClosetCompartmentStyle.box;
    final a = context.armoire;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(DsSpacing.md, DsSpacing.md, DsSpacing.md, 0),
        sliver: lined
            ? DecoratedSliver(
                // The lining of a drawer, or the inside of a box.
                decoration: BoxDecoration(
                  gradient: style == ClosetCompartmentStyle.box
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [a.lacquer, a.lacquerDeep],
                        )
                      : RadialGradient(
                          center: const Alignment(-.3, -.8),
                          radius: 1.6,
                          colors: [a.velvet, a.velvetDeep],
                        ),
                  borderRadius: DsRadius.borderLg,
                  border: Border.all(color: a.inlay),
                  boxShadow: [
                    BoxShadow(
                      color: a.shade.withValues(alpha: .35),
                      blurRadius: DsSpacing.sm,
                      offset: const Offset(0, DsSpacing.xxs),
                    ),
                  ],
                ),
                sliver: SliverPadding(
                  padding: const EdgeInsets.all(DsSpacing.sm),
                  sliver: list,
                ),
              )
            : list,
      ),
      if (page.hasMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(DsSpacing.lg),
            child: Center(child: DsLoadingIndicator()),
          ),
        ),
    ];
  }

  List<ClosetItem> _sorted(List<ClosetItem> items) {
    if (_sort == ClosetSort.recent) return items;
    final sorted = [...items];
    switch (_sort) {
      case ClosetSort.mostWorn:
        sorted.sort((a, b) => b.wearCount.compareTo(a.wearCount));
      case ClosetSort.leastWorn:
        // Never worn first, then the longest since she last reached for it.
        sorted.sort((a, b) {
          final byCount = a.wearCount.compareTo(b.wearCount);
          if (byCount != 0) return byCount;
          final aDays = a.daysSinceWorn ?? 1 << 20;
          final bDays = b.daysSinceWorn ?? 1 << 20;
          return bDays.compareTo(aDays);
        });
      case ClosetSort.recent:
        break;
    }
    return sorted;
  }
}

int _columnsFor(ClosetCompartmentStyle style) => switch (style) {
  ClosetCompartmentStyle.rail ||
  ClosetCompartmentStyle.hooks ||
  ClosetCompartmentStyle.rack => 2,
  _ => 3,
};

// ── The header: the drawer front she pulled ──────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.name,
    required this.caption,
    required this.icon,
    required this.actions,
  });

  final String name;
  final String? caption;
  final IconData icon;
  final List<Widget> actions;

  static const double _front = DsSizes.avatarHero + DsSpacing.huge;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: DsSizes.appBarHeight + _front,
      backgroundColor: a.lacquer,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: a.ink),
      actionsIconTheme: IconThemeData(color: a.ink),
      leading: IconButton(
        icon: Icon(DsIcons.back, size: DsSizes.iconSm, color: a.ink),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => popOrHome(context),
      ),
      actions: [...actions, DsGaps.hXxs],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = MediaQuery.paddingOf(context).top;
          final collapsed = DsSizes.appBarHeight + top;
          final expanded = DsSizes.appBarHeight + _front + top;
          final t = ((constraints.maxHeight - collapsed) / (expanded - collapsed)).clamp(
            0.0,
            1.0,
          );
          return _DrawerFrontArt(
            openness: t,
            name: name,
            caption: caption,
            icon: icon,
            topInset: top,
          );
        },
      ),
    );
  }
}

class _DrawerFrontArt extends StatelessWidget {
  const _DrawerFrontArt({
    required this.openness,
    required this.name,
    required this.caption,
    required this.icon,
    required this.topInset,
  });

  final double openness;
  final String name;
  final String? caption;
  final IconData icon;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final barOpacity = (1 - openness * 2.4).clamp(0.0, 1.0);
    final openOpacity = ((openness - .3) / .7).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: a.lacquerGradient,
        border: Border(bottom: BorderSide(color: a.brass, width: DsSpacing.xxxs)),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .45),
            blurRadius: DsSpacing.md,
            offset: const Offset(0, DsSpacing.xs),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The raised panel of the front, inside its bevel.
          if (openOpacity > 0)
            Positioned(
              left: DsSpacing.md,
              right: DsSpacing.md,
              top: topInset + DsSizes.appBarHeight - DsSpacing.xs,
              bottom: DsSpacing.md,
              child: Opacity(
                opacity: openOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: DsRadius.borderMd,
                    border: Border.all(color: a.inlay),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpacing.xxs),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: DsRadius.borderSm,
                        border: Border.all(
                          color: DsColors.white.withValues(alpha: a.isDark ? .07 : .7),
                        ),
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ArmoirePlaque(
                                large: true,
                                icon: icon,
                                label: name,
                                caption: caption,
                              ),
                              DsGaps.vSm,
                              const ArmoirePull(width: DsSizes.thumbMd),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (barOpacity > 0)
            Positioned(
              top: topInset,
              left: DsSizes.appBarHeight + DsSpacing.huge,
              right: DsSizes.appBarHeight + DsSpacing.huge,
              height: DsSizes.appBarHeight,
              child: Opacity(
                opacity: barOpacity,
                child: Center(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.sectionTitle.displayFamily.bold.tint(a.ink),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onSort});

  final ClosetSort sort;
  final ValueChanged<ClosetSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(ClosetSort value) => switch (value) {
      ClosetSort.recent => l10n.closetSortRecent,
      ClosetSort.mostWorn => l10n.closetSortMostWorn,
      ClosetSort.leastWorn => l10n.closetSortLeastWorn,
    };

    return PopupMenuButton<ClosetSort>(
      tooltip: l10n.closetSortTooltip,
      initialValue: sort,
      onSelected: onSort,
      icon: const Icon(Icons.swap_vert_rounded),
      itemBuilder: (context) => [
        for (final value in ClosetSort.values)
          CheckedPopupMenuItem(
            value: value,
            checked: value == sort,
            child: Text(label(value)),
          ),
      ],
    );
  }
}

// ── The inside ────────────────────────────────────────────────────────────

/// One row of a compartment, with what holds it: the rod and hangers above
/// it, the board under it, pegs, or velvet cushions round each piece.
class _InteriorRow extends StatelessWidget {
  const _InteriorRow({
    required this.style,
    required this.columns,
    required this.items,
    required this.tile,
  });

  final ClosetCompartmentStyle style;
  final int columns;
  final List<ClosetItem> items;
  final Widget Function(ClosetItem item, bool dense) tile;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final dense = columns > 2;
    final textBlock = MediaQuery.textScalerOf(context).scale(dense ? DsSpacing.xxl : DsSpacing.xxxl) +
        DsSpacing.xs;
    final aspect = switch (style) {
      ClosetCompartmentStyle.rail => .7,
      ClosetCompartmentStyle.rack => 1.0,
      _ => .86,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = style == ClosetCompartmentStyle.drawer || style == ClosetCompartmentStyle.box
            ? DsSpacing.xs
            : DsSpacing.sm;
        final cell = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final inset = style == ClosetCompartmentStyle.drawer || style == ClosetCompartmentStyle.box
            ? DsSpacing.xs
            : 0.0;
        final tileHeight = (cell - inset * 2) / aspect + textBlock;

        Widget holder(ClosetItem item) {
          final piece = SizedBox(height: tileHeight, child: tile(item, dense));
          return switch (style) {
            ClosetCompartmentStyle.rail => Column(
              children: [
                ArmoireHanger(width: cell * .5, height: DsSpacing.lg),
                piece,
              ],
            ),
            ClosetCompartmentStyle.hooks => Column(
              children: [
                const ArmoirePeg(size: DsSpacing.md),
                Container(
                  width: DsSpacing.xxxs,
                  height: DsSpacing.sm,
                  color: a.brassDeep,
                ),
                piece,
              ],
            ),
            ClosetCompartmentStyle.drawer || ClosetCompartmentStyle.box => ArmoireCushion(
              child: Padding(padding: EdgeInsets.all(inset), child: piece),
            ),
            _ => piece,
          };
        }

        final cells = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: cell,
                child: i < items.length ? holder(items[i]) : null,
              ),
            ],
          ],
        );

        return switch (style) {
          ClosetCompartmentStyle.rail => Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.lg),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: DsSpacing.xxs),
                  child: cells,
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ArmoireRail(height: DsSpacing.sm),
                ),
              ],
            ),
          ),
          ClosetCompartmentStyle.shelf || ClosetCompartmentStyle.rack => Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.md),
            child: Column(
              children: [
                cells,
                DsGaps.vXs,
                ArmoirePlank(
                  height: DsSpacing.md,
                  slant: style == ClosetCompartmentStyle.rack,
                ),
              ],
            ),
          ),
          ClosetCompartmentStyle.hooks => Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.lg),
            child: cells,
          ),
          _ => Padding(padding: EdgeInsets.only(bottom: gap), child: cells),
        };
      },
    );
  }
}

/// An empty compartment, drawn empty — the rod with bare hangers, a bare
/// board, an empty tray — with the one thing worth doing about it.
class _EmptyInterior extends StatelessWidget {
  const _EmptyInterior({
    required this.compartment,
    required this.filtering,
    required this.onClear,
    required this.onAdd,
  });

  final ClosetCompartment compartment;
  final bool filtering;
  final VoidCallback onClear;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.dsText;
    final a = context.armoire;

    final (title, body) = filtering
        ? (l10n.closetFilterEmptyTitle, l10n.closetFilterEmptyBody)
        : switch (compartment) {
            ClosetCompartment(isFavourites: true) => (
              l10n.closetFavouritesEmptyTitle,
              l10n.closetFavouritesEmptyBody,
            ),
            ClosetCompartment(isStored: true) => (
              l10n.closetStoredEmptyTitle,
              l10n.closetStoredEmptyBody,
            ),
            ClosetCompartment(isSlot: false) => (l10n.closetEmptyTitle, l10n.closetEmptyBody),
            ClosetCompartment(style: ClosetCompartmentStyle.rail) ||
            ClosetCompartment(style: ClosetCompartmentStyle.hooks) => (
              l10n.closetCompartmentEmptyRail,
              l10n.closetCompartmentEmptyBody,
            ),
            ClosetCompartment(style: ClosetCompartmentStyle.drawer) => (
              l10n.closetCompartmentEmptyDrawer,
              l10n.closetCompartmentEmptyBody,
            ),
            _ => (l10n.closetCompartmentEmptyShelf, l10n.closetCompartmentEmptyBody),
          };

    final art = switch (compartment.style) {
      ClosetCompartmentStyle.rail || ClosetCompartmentStyle.hooks => Column(
        children: [
          const ArmoireRail(height: DsSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 3; i++)
                const Opacity(
                  opacity: .6,
                  child: ArmoireHanger(width: DsSizes.avatarLg, height: DsSpacing.xl),
                ),
            ],
          ),
        ],
      ),
      ClosetCompartmentStyle.drawer || ClosetCompartmentStyle.box => SizedBox(
        height: DsSizes.thumbMd,
        child: ArmoireVelvet(
          child: Padding(
            padding: const EdgeInsets.all(DsSpacing.xs),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) DsGaps.hXs,
                  const Expanded(child: ArmoireCushion(child: SizedBox.expand())),
                ],
              ],
            ),
          ),
        ),
      ),
      _ => Column(
        children: [
          SizedBox(
            height: DsSizes.thumbSm,
            child: Center(
              child: Icon(
                compartment.icon,
                size: DsSizes.iconXl,
                color: a.brass.withValues(alpha: .6),
              ),
            ),
          ),
          ArmoirePlank(
            height: DsSpacing.md,
            slant: compartment.style == ClosetCompartmentStyle.rack,
          ),
        ],
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpacing.xl, DsSpacing.xl, DsSpacing.xl, DsSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          art,
          DsGaps.vXl,
          Text(title, textAlign: TextAlign.center, style: text.sectionTitle.tint(a.ink)),
          DsGaps.vXs,
          Text(body, textAlign: TextAlign.center, style: text.bodyMuted),
          DsGaps.vLg,
          if (filtering)
            DsButton(
              label: l10n.closetClearFilters,
              icon: Icons.filter_alt_off_rounded,
              variant: DsButtonVariant.secondary,
              onPressed: onClear,
            )
          else if (onAdd != null)
            DsButton(
              label: l10n.closetCompartmentAddFirst,
              icon: Icons.add_a_photo_outlined,
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

class _InteriorSkeleton extends StatelessWidget {
  const _InteriorSkeleton({required this.style});

  final ClosetCompartmentStyle style;

  @override
  Widget build(BuildContext context) {
    final columns = _columnsFor(style);
    return SliverPadding(
      padding: const EdgeInsets.all(DsSpacing.md),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: DsSpacing.md,
          crossAxisSpacing: DsSpacing.sm,
          childAspectRatio: columns == 2 ? .62 : .66,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const DsShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: DsSkeleton.box(height: double.infinity)),
                DsGaps.vXs,
                DsSkeleton.line(),
                DsGaps.vXxs,
                DsSkeleton.line(width: DsSizes.thumbMd),
              ],
            ),
          ),
          childCount: math.max(columns * 2, 4),
        ),
      ),
    );
  }
}

/// The "+" at the foot of an open compartment.
class _AddBar extends StatelessWidget {
  const _AddBar({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: a.lacquerGradient,
        border: Border(top: BorderSide(color: a.inlay)),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .3),
            blurRadius: DsSpacing.md,
            offset: const Offset(0, -DsSpacing.xxs),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, DsSpacing.sm),
          child: DsButton(
            label: label,
            icon: Icons.add_rounded,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
