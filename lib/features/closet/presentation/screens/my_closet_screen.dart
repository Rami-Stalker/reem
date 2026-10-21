import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
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
        title: 'خزانتي',
        actions: [
          IconButton(
            tooltip: 'إطلالاتي',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => context.push(RoutePaths.closetLooks),
          ),
          IconButton(
            tooltip: 'شو ألبس اليوم؟',
            icon: const Icon(Icons.wb_twilight_rounded),
            onPressed: () => context.push(RoutePaths.closetToday),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.closetAddItem),
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('ضيفي قطعة'),
      ),
      body: overviewAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نفتح خزانتك.',
          onRetry: () => ref.invalidate(closetOverviewProvider),
        ),
        data: (overview) => overview.isEmpty
            ? _EmptyCloset(overview: overview)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(closetOverviewProvider),
                child: _Body(
                  overview: overview,
                  slot: _slot,
                  onSlot: (slot) => setState(() => _slot = slot),
                ),
              ),
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
          title: 'خزانتك لسا فاضية',
          message:
              'حطّي فيها قطعك — يلي اشتريتيها من أوهارا ويلي عندك من قبل. '
              'من هون منعرف شو بينقصك وشو بتقدري تلبسي.',
          actionLabel: 'جيبي مشترياتي',
          onAction: () => _backfill(context, ref),
          secondaryActionLabel: 'ضيفي قطعة بصورة',
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
            ? 'ضفنا $added قطعة من طلباتك.'
            : 'ما لقينا طلبات مسلّمة بعد.',
      ),
      error: (_) => DsSnackbar.show(
        context,
        message: 'ما قدرنا نجيب مشترياتك هلق.',
      ),
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
                message: 'ما قدرنا نعرض قطعك.',
                onRetry: () => ref.invalidate(closetItemsProvider),
              ),
            ),
          ),
          data: (page) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.sm,
              DsSpacing.md,
              DsSpacing.xxl,
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
                  label: 'إطلالة ممكنة',
                ),
                _Metric(value: '${overview.itemsCount}', label: 'قطعة'),
                _Metric(value: '${overview.looksCount}', label: 'إطلالة محفوظة'),
                _Metric(value: '${overview.wornThisMonth}', label: 'لبسة هالشهر'),
              ],
            ),
            if (overview.cannotDress) ...[
              const SizedBox(height: DsSpacing.sm),
              Text(
                'قطعك موجودة بس ما بتكوّن إطلالة كاملة للجو الحالي.',
                style: context.dsText.caption.tint(colors.warning),
              ),
            ] else if (overview.outfitCapacity > overview.seasonOutfitCapacity) ...[
              const SizedBox(height: DsSpacing.sm),
              // The seasonal story, in one line: the difference between the two
              // numbers is clothes she owns and cannot wear right now.
              Text(
                'عندك ${overview.outfitCapacity} إطلالة بالمجمل، '
                '${overview.seasonOutfitCapacity} منها مناسبة للـ${overview.seasonLabel}.',
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
          child: Text('شو بينقص خزانتك', style: context.dsText.sectionTitle),
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
              label: 'الكل',
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
