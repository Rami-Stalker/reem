import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_home_sections.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_item_tile.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_wear_feedback.dart';
import 'package:ohara/features/market/presentation/widgets/market_entry_card.dart';

/// خزانتي — the closet's front page.
///
/// The order of the screen is an argument. What her wardrobe can do comes
/// first, then what she can wear today, then the pieces she has forgotten,
/// then what it is short of, and then the wardrobe itself to browse. A shop
/// would invert that and lead with the gaps; a wardrobe that opens with a
/// shopping list is a catalog that has learned her sizes.
class MyClosetScreen extends ConsumerStatefulWidget {
  const MyClosetScreen({super.key});

  @override
  ConsumerState<MyClosetScreen> createState() => _MyClosetScreenState();
}

/// How the wardrobe grid is ordered. Applied to the pieces loaded so far.
enum ClosetSort { recent, mostWorn, leastWorn }

class _MyClosetScreenState extends ConsumerState<MyClosetScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  String? _slot;
  bool _favourites = false;
  bool _shelved = false;
  String _query = '';
  ClosetSort _sort = ClosetSort.recent;
  bool _dense = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  ClosetItemQuery get _itemQuery => ClosetItemQuery(
    slot: _slot,
    status: _shelved ? ClosetItemStatus.archived : null,
    favouritesOnly: _favourites ? true : null,
    search: _query.isEmpty ? null : _query,
    limit: 48,
  );

  void _onSearch(String value) {
    _debounce?.cancel();
    // A request per keystroke would be a request per letter of "فستان".
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _slot = null;
      _favourites = false;
      _shelved = false;
      _query = '';
    });
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(closetOverviewProvider)
      ..invalidate(closetWardrobeProvider)
      ..invalidate(todayOutfitsProvider)
      ..invalidate(closetGapsProvider);
    try {
      await ref.read(closetOverviewProvider.future);
    } catch (_) {
      // The page draws its own error state; the spinner only needs to stop.
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(closetOverviewProvider);
    final l10n = context.l10n;

    final appBar = PremiumAppBar(
      title: l10n.navCloset,
      subtitle: overviewAsync.asData?.value.seasonLabel.isNotEmpty == true
          ? l10n.closetSeasonNow(overviewAsync.asData!.value.seasonLabel)
          : null,
      // A tab when she reaches it from the bar, a pushed page when she
      // reaches it from a product: only the second has somewhere to go back.
      showBack: GoRouter.of(context).canPop(),
      actions: [
        IconButton(
          tooltip: l10n.closetAddPiece,
          icon: const Icon(Icons.add_a_photo_rounded),
          onPressed: () => context.push(RoutePaths.closetAddItem),
        ),
      ],
    );

    return OharaScrollPage(
      onRefresh: _refresh,
      slivers: [
        appBar,
        ...overviewAsync.when(
          loading: () => const [SliverToBoxAdapter(child: _ClosetSkeleton())],
          error: (_, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: DsErrorState(
                message: l10n.closetLoadFailed,
                onRetry: () => ref.invalidate(closetOverviewProvider),
              ),
            ),
          ],
          data: (overview) => overview.isEmpty
              ? const [SliverToBoxAdapter(child: _EmptyCloset())]
              : _content(context, overview),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  List<Widget> _content(BuildContext context, ClosetOverview overview) {
    final wardrobeAsync = ref.watch(closetWardrobeProvider(_itemQuery));
    final filtering =
        _slot != null || _favourites || _shelved || _query.isNotEmpty;

    return [
      DsGaps.sliverSm,
      SliverToBoxAdapter(child: ClosetPulseCard(overview: overview)),
      DsGaps.sliverLg,
      const SliverToBoxAdapter(child: ClosetJourney()),
      DsGaps.sliverLg,
      SliverToBoxAdapter(child: ClosetQuickActions(overview: overview)),
      DsGaps.sliverXl,
      const SliverToBoxAdapter(child: ClosetTodayPick()),
      if (overview.neglected.isNotEmpty) ...[
        DsGaps.sliverXl,
        SliverToBoxAdapter(
          child: ClosetRediscoverRail(items: overview.neglected),
        ),
      ],
      if (overview.gaps.isNotEmpty) ...[
        DsGaps.sliverXl,
        SliverToBoxAdapter(child: ClosetGapRail(gaps: overview.gaps)),
      ],
      // Phase four's way in, and it renders nothing when nothing needs
      // attention — which is most days, and is the point.
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: DsSpacing.md),
          child: WardrobeCareEntryCard(),
        ),
      ),
      DsGaps.sliverXl,
      SliverToBoxAdapter(
        child: _WardrobeHeader(
          count: overview.itemsCount,
          sort: _sort,
          dense: _dense,
          onSort: (value) => setState(() => _sort = value),
          onDensity: () => setState(() => _dense = !_dense),
        ),
      ),
      DsGaps.sliverSm,
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: DsInputField.search(
            controller: _search,
            hint: context.l10n.closetSearchHint,
            onChanged: _onSearch,
            onClear: () {
              _debounce?.cancel();
              setState(() => _query = '');
            },
          ),
        ),
      ),
      DsGaps.sliverXs,
      SliverToBoxAdapter(
        child: _FilterRail(
          counts: overview.slotCounts,
          archivedCount: overview.archivedCount,
          slot: _slot,
          favourites: _favourites,
          shelved: _shelved,
          onSlot: (slot) => setState(() => _slot = slot),
          onFavourites: () => setState(() => _favourites = !_favourites),
          onShelved: () => setState(() => _shelved = !_shelved),
        ),
      ),
      ...wardrobeAsync.when(
        loading: () => [_GridSkeleton(dense: _dense)],
        error: (_, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              child: DsErrorState(
                message: context.l10n.closetItemsFailed,
                onRetry: () => ref.invalidate(closetWardrobeProvider),
              ),
            ),
          ),
        ],
        data: (page) => _grid(context, page, filtering: filtering),
      ),
    ];
  }

  List<Widget> _grid(
    BuildContext context,
    ClosetItemPage page, {
    required bool filtering,
  }) {
    if (page.items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(DsSpacing.lg),
            child: DsEmptyState(
              icon: _shelved
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              title: _shelved
                  ? context.l10n.closetShelvedEmpty
                  : context.l10n.closetFilterEmptyTitle,
              message: context.l10n.closetFilterEmptyBody,
              actionLabel: filtering ? context.l10n.closetClearFilters : null,
              onAction: filtering ? _clearFilters : null,
            ),
          ),
        ),
      ];
    }

    final items = _sorted(page.items);
    final notifier = ref.read(closetWardrobeProvider(_itemQuery).notifier);
    final columns = _dense ? 3 : 2;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.sm,
          DsSpacing.lg,
          0,
        ),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: DsSpacing.md,
            crossAxisSpacing: DsSpacing.sm,
            childAspectRatio: _dense ? 0.6 : 0.66,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            // Reaching the last row asks for the next page, so a long
            // wardrobe scrolls as one grid rather than ending in a button.
            if (page.hasMore && index >= items.length - columns * 2) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => notifier.loadMore(),
              );
            }
            final item = items[index];
            return DsStaggerAnimations.item(
              index: index,
              child: ClosetItemTile(
                item: item,
                dense: _dense,
                showWear: item.status == ClosetItemStatus.active,
                onTap: () => context.push(RoutePaths.closetItemOf(item.id)),
                onWear: () => logClosetWear(
                  context,
                  ref,
                  item,
                  onChanged: notifier.replace,
                ),
              ),
            );
          }, childCount: items.length),
        ),
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

// ── The wardrobe section ──────────────────────────────────────────────────

class _WardrobeHeader extends StatelessWidget {
  const _WardrobeHeader({
    required this.count,
    required this.sort,
    required this.dense,
    required this.onSort,
    required this.onDensity,
  });

  final int count;
  final ClosetSort sort;
  final bool dense;
  final ValueChanged<ClosetSort> onSort;
  final VoidCallback onDensity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.boutique;
    final text = context.dsText;

    String label(ClosetSort value) => switch (value) {
      ClosetSort.recent => l10n.closetSortRecent,
      ClosetSort.mostWorn => l10n.closetSortMostWorn,
      ClosetSort.leastWorn => l10n.closetSortLeastWorn,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.closetWardrobeEyebrow(count),
                  style: text.overline.tint(palette.primary),
                ),
                DsGaps.vXxxs,
                Text(
                  l10n.closetWardrobeTitle,
                  style: text.sectionTitle.tint(palette.ink),
                ),
              ],
            ),
          ),
          PopupMenuButton<ClosetSort>(
            tooltip: l10n.closetSortTooltip,
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (context) => [
              for (final value in ClosetSort.values)
                CheckedPopupMenuItem(
                  value: value,
                  checked: value == sort,
                  child: Text(label(value)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: DsSizes.iconSm,
                    color: palette.primary,
                  ),
                  DsGaps.hXxs,
                  Text(label(sort), style: text.captionStrong.tint(palette.primary)),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: dense ? l10n.closetViewLarge : l10n.closetViewCompact,
            onPressed: onDensity,
            icon: Icon(
              dense ? Icons.grid_view_rounded : Icons.view_module_rounded,
              color: palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The wardrobe's filter rail, findable from a test.
const closetFilterRailKey = ValueKey('closet-filter-rail'); // l10n-ignore: a widget key, not copy

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.counts,
    required this.archivedCount,
    required this.slot,
    required this.favourites,
    required this.shelved,
    required this.onSlot,
    required this.onFavourites,
    required this.onShelved,
  });

  final List<SlotCount> counts;
  final int archivedCount;
  final String? slot;
  final bool favourites;
  final bool shelved;
  final ValueChanged<String?> onSlot;
  final VoidCallback onFavourites;
  final VoidCallback onShelved;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Only slots she actually owns something in. Offering the full lexicon
    // would fill the rail with filters that return nothing.
    return SizedBox(
      height: DsSizes.controlLg,
      child: ListView(
        key: closetFilterRailKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.xxs,
        ),
        children: [
          DsChip(
            label: l10n.closetAll,
            selected: slot == null && !favourites && !shelved,
            onTap: () {
              onSlot(null);
              if (favourites) onFavourites();
              if (shelved) onShelved();
            },
          ),
          DsGaps.hXs,
          DsChip(
            label: l10n.closetFilterFavourites,
            icon: favourites
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            selected: favourites,
            onTap: onFavourites,
          ),
          for (final entry in counts) ...[
            DsGaps.hXs,
            DsChip(
              label: entry.label,
              icon: ClosetSlotStyle.icon(entry.slot),
              count: entry.count,
              selected: slot == entry.slot,
              onTap: () => onSlot(slot == entry.slot ? null : entry.slot),
            ),
          ],
          // Shelved pieces had no way back into view: once put away for the
          // season, a piece could only be found again from a link to it.
          if (archivedCount > 0) ...[
            DsGaps.hXs,
            DsChip(
              label: l10n.closetFilterShelved,
              icon: Icons.inventory_2_outlined,
              count: archivedCount,
              selected: shelved,
              onTap: onShelved,
            ),
          ],
        ],
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────

/// The first-run state.
///
/// Leads with the backfill, because it is the difference between a feature that
/// works this afternoon and one she has to build by hand over a fortnight. The
/// gap engine reasoning over three garments gives advice worse than none, so
/// filling the closet is the only thing worth asking for here — and the three
/// steps under it say what she gets for doing it.
class _EmptyCloset extends ConsumerStatefulWidget {
  const _EmptyCloset();

  @override
  ConsumerState<_EmptyCloset> createState() => _EmptyClosetState();
}

class _EmptyClosetState extends ConsumerState<_EmptyCloset> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.boutique;
    final text = context.dsText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: palette.signatureGradient,
              borderRadius: DsRadius.borderCard,
              boxShadow: palette.shadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.xl),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DsSpacing.md),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DsColors.onMedia.withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.checkroom_rounded,
                      size: DsSizes.iconXl,
                      color: DsColors.onMedia,
                    ),
                  ),
                  DsGaps.vMd,
                  Text(
                    l10n.closetEmptyTitle,
                    textAlign: TextAlign.center,
                    style: text.pageTitle.tint(DsColors.onMedia),
                  ),
                  DsGaps.vXs,
                  Text(
                    l10n.closetEmptyBody,
                    textAlign: TextAlign.center,
                    style: text.body.tint(DsColors.onMediaMuted),
                  ),
                ],
              ),
            ),
          ),
          DsGaps.vLg,
          CustomerPrimaryButton(
            label: l10n.closetBringPurchases,
            icon: Icons.local_shipping_outlined,
            isLoading: _importing,
            onPressed: _backfill,
          ),
          DsGaps.vSm,
          DsButton(
            label: l10n.closetAddWithPhoto,
            icon: Icons.add_a_photo_outlined,
            variant: DsButtonVariant.secondary,
            onPressed: () => context.push(RoutePaths.closetAddItem),
          ),
          DsGaps.vXl,
          Text(l10n.closetHowItWorks, style: text.sectionTitle),
          DsGaps.vSm,
          _Step(
            index: 1,
            icon: Icons.add_a_photo_rounded,
            title: l10n.closetStepAddTitle,
            body: l10n.closetStepAddBody,
          ),
          _Step(
            index: 2,
            icon: Icons.auto_awesome_rounded,
            title: l10n.closetStepLooksTitle,
            body: l10n.closetStepLooksBody,
          ),
          _Step(
            index: 3,
            icon: Icons.insights_rounded,
            title: l10n.closetStepGapsTitle,
            body: l10n.closetStepGapsBody,
          ),
          DsGaps.vLg,
          const ClosetJourney(),
        ],
      ),
    );
  }

  Future<void> _backfill() async {
    setState(() => _importing = true);
    final result = await ref.read(closetActionsProvider).backfill();
    if (!mounted) return;
    setState(() => _importing = false);

    result.when(
      success: (added) => DsSnackbar.show(
        context,
        message: added > 0
            ? context.l10n.closetBackfilled(added)
            : context.l10n.closetNoDeliveredOrders,
        type: added > 0 ? DsSnackbarType.success : DsSnackbarType.info,
      ),
      error: (_) => DsSnackbar.show(
        context,
        message: context.l10n.closetBackfillFailed,
        type: DsSnackbarType.error,
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int index;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: CustomerPanel(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          children: [
            Container(
              width: DsSizes.avatarMd,
              height: DsSizes.avatarMd,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.primarySoft,
              ),
              child: Icon(icon, size: DsSizes.iconSm, color: palette.primary),
            ),
            DsGaps.hSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.labelStrong),
                  DsGaps.vXxxs,
                  Text(body, style: text.caption),
                ],
              ),
            ),
            Text(
              '$index',
              style: text.metric.tint(palette.gold.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosetSkeleton extends StatelessWidget {
  const _ClosetSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.box(height: DsSizes.avatarHero * 2.4),
            DsGaps.vLg,
            Row(
              children: [
                Expanded(child: DsSkeleton.box(height: DsSizes.thumbLg)),
                DsGaps.hXs,
                Expanded(child: DsSkeleton.box(height: DsSizes.thumbLg)),
                DsGaps.hXs,
                Expanded(child: DsSkeleton.box(height: DsSizes.thumbLg)),
                DsGaps.hXs,
                Expanded(child: DsSkeleton.box(height: DsSizes.thumbLg)),
              ],
            ),
            DsGaps.vXl,
            DsSkeleton.line(width: DsSizes.railCardWidth),
            DsGaps.vSm,
            DsSkeleton.box(height: DsSizes.railCardHeight),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        0,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: dense ? 3 : 2,
          mainAxisSpacing: DsSpacing.md,
          crossAxisSpacing: DsSpacing.sm,
          childAspectRatio: dense ? 0.6 : 0.66,
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
          childCount: 6,
        ),
      ),
    );
  }
}
