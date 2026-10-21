import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/closet/domain/entities/closet_overview.dart';
import 'package:reem/features/closet/domain/repositories/closet_repository.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';
import 'package:reem/features/closet/presentation/widgets/closet_gap_card.dart';
import 'package:reem/features/closet/presentation/widgets/closet_item_tile.dart';
import 'package:reem/features/market/presentation/widgets/market_entry_card.dart';

/// خزانتي — the closet's front page.
///
/// The order of the screen is an argument. Her wardrobe comes first, then what
/// she can wear today, then what it is short of. A shop would invert that and
/// lead with the gaps; a wardrobe that opens with a shopping list is a catalog
/// that has learned her sizes.
class MyClosetScreen extends ConsumerStatefulWidget {
  const MyClosetScreen({super.key});

  @override
  ConsumerState<MyClosetScreen> createState() => _MyClosetScreenState();
}

class _MyClosetScreenState extends ConsumerState<MyClosetScreen> {
  String? _slot;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final overviewAsync = ref.watch(closetOverviewProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(
        title: context.l10n.navCloset,
        // A tab when she reaches it from the bar, a pushed page when she
        // reaches it from a product: only the second has somewhere to go back.
        showBack: GoRouter.of(context).canPop(),
        actions: [
          // In the bar rather than a floating button: the closet is a tab
          // now, and a button floating at the foot of a tab sits under the
          // floating navigation bar.
          IconButton(
            tooltip: context.l10n.closetAddPiece,
            icon: const Icon(Icons.add_a_photo_rounded),
            onPressed: () => context.push(RoutePaths.closetAddItem),
          ),
          IconButton(
            tooltip: context.l10n.closetMyLooks,
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => context.push(RoutePaths.closetLooks),
          ),
          IconButton(
            tooltip: context.l10n.closetWhatToWearToday,
            icon: const Icon(Icons.wb_twilight_rounded),
            onPressed: () => context.push(RoutePaths.closetToday),
          ),
        ],
      ),
      body: Column(
        children: [
          const _Spectrum(),
          Expanded(
            child: overviewAsync.when(
              loading: () => const Center(child: DsLoadingIndicator()),
              error: (_, _) => DsErrorState(
                message: context.l10n.closetLoadFailed,
                onRetry: () => ref.invalidate(closetOverviewProvider),
              ),
              data: (overview) => overview.isEmpty
                  ? _EmptyCloset(overview: overview)
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(closetOverviewProvider),
                      child: _Body(
                        overview: overview,
                        slot: _slot,
                        onSlot: (slot) => setState(() => _slot = slot),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Room under the last row for the floating bottom bar — the same clearance
/// the home feed leaves.
const double _clearsBottomBar = 120;

/// أريد · أفكّر فيها · عندي — one piece's life, read left to right.
///
/// The wishlist, Rooms and the closet used to be three unrelated corners of
/// the app. They are one journey: a piece she wants, then a piece she is
/// deciding on with her friends, then a piece she owns. The closet is the
/// last step and the one this tab shows; the other two are a tap away, and
/// this is the door Rooms kept when it gave its tab to the closet.
class _Spectrum extends StatelessWidget {
  const _Spectrum();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.sm,
        DsSpacing.md,
        DsSpacing.xxs,
      ),
      child: Row(
        children: [
          DsChip(
            label: context.l10n.closetSpectrumWant,
            icon: Icons.favorite_border_rounded,
            onTap: () => context.push(RoutePaths.favorites),
          ),
          DsGaps.hXs,
          DsChip(
            label: context.l10n.closetSpectrumDeciding,
            icon: Icons.meeting_room_outlined,
            onTap: () => context.push(RoutePaths.rooms),
          ),
          DsGaps.hXs,
          // The step she is on. Without a handler DsChip draws it as
          // unavailable, which is the opposite of what it is.
          DsChip(
            label: context.l10n.closetSpectrumOwn,
            icon: Icons.checkroom_rounded,
            selected: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

/// The first-run state.
///
/// Leads with the backfill, because it is the difference between a feature that
/// works this afternoon and one she has to build by hand over a fortnight. The
/// gap engine reasoning over three garments gives advice worse than none, so
/// filling the closet is the only thing worth asking for here.
class _EmptyCloset extends ConsumerWidget {
  const _EmptyCloset({required this.overview});

  final ClosetOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(DsSpacing.lg),
      children: [
        DsEmptyState(
          icon: Icons.checkroom_rounded,
          title: context.l10n.closetEmptyTitle,
          message: context.l10n.closetEmptyBody,
          actionLabel: context.l10n.closetBringPurchases,
          onAction: () => _backfill(context, ref),
          secondaryActionLabel: context.l10n.closetAddWithPhoto,
          onSecondaryAction: () => context.push(RoutePaths.closetAddItem),
        ),
      ],
    );
  }

  Future<void> _backfill(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(closetActionsProvider).backfill();
    if (!context.mounted) return;

    result.when(
      success: (added) => DsSnackbar.show(
        context,
        message: added > 0
            ? context.l10n.closetBackfilled(added)
            : context.l10n.closetNoDeliveredOrders,
      ),
      error: (_) =>
          DsSnackbar.show(context, message: context.l10n.closetBackfillFailed),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.overview, required this.slot, required this.onSlot});

  final ClosetOverview overview;
  final String? slot;
  final ValueChanged<String?> onSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(
      closetItemsProvider(ClosetItemQuery(slot: slot, limit: 60)),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header(overview: overview)),
        if (overview.gaps.isNotEmpty)
          SliverToBoxAdapter(child: _GapRail(overview: overview)),
        // Phase four's way in, and it renders nothing when nothing needs
        // attention — which is most days, and is the point. What she owns
        // comes before what to do about it.
        const SliverToBoxAdapter(child: WardrobeCareEntryCard()),
        SliverToBoxAdapter(
          child: _SlotFilter(
            counts: overview.slotCounts,
            selected: slot,
            onSelected: onSlot,
          ),
        ),
        itemsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(DsSpacing.xl),
              child: Center(child: DsLoadingIndicator()),
            ),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              child: DsErrorState(
                message: context.l10n.closetItemsFailed,
                onRetry: () => ref.invalidate(closetItemsProvider),
              ),
            ),
          ),
          data: (page) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.sm,
              DsSpacing.md,
              _clearsBottomBar,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: DsSpacing.sm,
                crossAxisSpacing: DsSpacing.sm,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = page.items[index];
                  return ClosetItemTile(
                    item: item,
                    onTap: () => context.push(RoutePaths.closetItemOf(item.id)),
                    onWear: () =>
                        ref.read(closetActionsProvider).logWear(item.id),
                  );
                },
                childCount: page.items.length,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The header numbers.
///
/// `outfit_capacity` is the headline rather than the item count, and that is
/// the whole editorial line of the feature: how many outfits her clothes make
/// is a fact about her wardrobe, where how many garments she owns is a fact
/// about her spending.
class _Header extends StatelessWidget {
  const _Header({required this.overview});

  final ClosetOverview overview;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.sm,
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Metric(
                  value: '${overview.seasonOutfitCapacity}',
                  label: context.l10n.closetMetricPossibleLooks,
                ),
                _Metric(
                  value: '${overview.itemsCount}',
                  label: context.l10n.closetMetricPieces,
                ),
                _Metric(
                  value: '${overview.looksCount}',
                  label: context.l10n.closetMetricSavedLooks,
                ),
                _Metric(
                  value: '${overview.wornThisMonth}',
                  label: context.l10n.closetMetricWornThisMonth,
                ),
              ],
            ),
            if (overview.cannotDress) ...[
              const SizedBox(height: DsSpacing.sm),
              Text(
                context.l10n.closetCannotDressSeason,
                style: context.dsText.caption.tint(colors.warning),
              ),
            ] else if (overview.outfitCapacity > overview.seasonOutfitCapacity) ...[
              const SizedBox(height: DsSpacing.sm),
              // The seasonal story, in one line: the difference between the two
              // numbers is clothes she owns and cannot wear right now.
              Text(
                context.l10n.closetSeasonCapacity(
                  overview.outfitCapacity,
                  overview.seasonOutfitCapacity,
                  overview.seasonLabel,
                ),
                style: context.dsText.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: context.dsText.metricSmall),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.dsText.metricLabel,
          ),
        ],
      ),
    );
  }
}

class _GapRail extends ConsumerWidget {
  const _GapRail({required this.overview});

  final ClosetOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.md,
            DsSpacing.sm,
            DsSpacing.md,
            DsSpacing.xs,
          ),
          child: Text(
            context.l10n.closetWhatsMissing,
            style: context.dsText.sectionTitle,
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
            itemCount: overview.gaps.length,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
            itemBuilder: (context, index) {
              final gap = overview.gaps[index];
              return SizedBox(
                width: 240,
                child: ClosetGapCard(
                  gap: gap,
                  compact: true,
                  onTap: () => context.push(RoutePaths.closetGapOf(gap.id)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SlotFilter extends StatelessWidget {
  const _SlotFilter({
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  final List<SlotCount> counts;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    // Only slots she actually owns something in. Offering the full lexicon
    // would fill the rail with filters that return nothing.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.md,
        0,
      ),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            DsChip(
              label: context.l10n.closetAll,
              selected: selected == null,
              onTap: () => onSelected(null),
            ),
            for (final entry in counts) ...[
              const SizedBox(width: DsSpacing.xs),
              DsChip(
                label: entry.label,
                count: entry.count,
                selected: selected == entry.slot,
                onTap: () => onSelected(entry.slot),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
