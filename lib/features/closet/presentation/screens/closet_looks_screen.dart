import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_look_card.dart';

/// Which looks the lookbook shows.
enum _LookFilter { all, ready, short, favourites }

/// إطلالاتي — the looks she has composed, as a lookbook.
///
/// A grid of collages rather than a list of rows: an outfit is something she
/// recognises by sight before she reads its name. The filter row splits the
/// book the one way that changes what she does next — the looks she can put
/// on now, and the looks one purchase away.
class ClosetLooksScreen extends ConsumerStatefulWidget {
  const ClosetLooksScreen({super.key});

  @override
  ConsumerState<ClosetLooksScreen> createState() => _ClosetLooksScreenState();
}

class _ClosetLooksScreenState extends ConsumerState<ClosetLooksScreen> {
  _LookFilter _filter = _LookFilter.all;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final looksAsync = ref.watch(closetLooksProvider(null));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(
        title: context.l10n.closetMyLooks,
        actions: [
          IconButton(
            tooltip: context.l10n.closetWhatToWearToday,
            icon: const Icon(Icons.wb_twilight_rounded),
            onPressed: () => context.push(RoutePaths.closetToday),
          ),
        ],
      ),
      body: looksAsync.when(
        loading: () => const _LooksSkeleton(),
        error: (_, _) => DsErrorState(
          message: context.l10n.closetLooksLoadFailed,
          onRetry: () => ref.invalidate(closetLooksProvider),
        ),
        data: (looks) => looks.isEmpty
            ? DsEmptyState(
                icon: Icons.auto_awesome_rounded,
                title: context.l10n.closetNoLooksTitle,
                message: context.l10n.closetNoLooksBody,
                actionLabel: context.l10n.closetSeeWhatToWear,
                onAction: () => context.push(RoutePaths.closetToday),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(closetLooksProvider),
                child: _Book(
                  looks: looks,
                  filter: _filter,
                  onFilter: (value) => setState(() => _filter = value),
                  onWear: _wear,
                ),
              ),
      ),
    );
  }

  Future<void> _wear(ClosetLook look) async {
    final result = await ref.read(closetActionsProvider).logLookWear(look.id);
    if (!mounted) return;
    DsSnackbar.show(
      context,
      message: result is Success
          ? context.l10n.closetTodayLogged
          : context.l10n.closetWearFailed,
      type: result is Success ? DsSnackbarType.success : DsSnackbarType.error,
    );
  }
}

class _Book extends StatelessWidget {
  const _Book({
    required this.looks,
    required this.filter,
    required this.onFilter,
    required this.onWear,
  });

  final List<ClosetLook> looks;
  final _LookFilter filter;
  final ValueChanged<_LookFilter> onFilter;
  final ValueChanged<ClosetLook> onWear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = looks.where((look) => look.isComplete).length;
    final short = looks.where((look) => look.isOnePieceShort).length;
    final favourites = looks.where((look) => look.isFavourite).length;

    final shown = switch (filter) {
      _LookFilter.all => looks,
      _LookFilter.ready => looks.where((look) => look.isComplete).toList(),
      _LookFilter.short => looks.where((look) => !look.isComplete).toList(),
      _LookFilter.favourites => looks.where((look) => look.isFavourite).toList(),
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.md,
              DsSpacing.md,
              DsSpacing.xs,
            ),
            child: _Summary(total: looks.length, ready: ready, short: short),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: DsSizes.controlLg,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.xxs,
              ),
              children: [
                DsChip(
                  label: l10n.closetAll,
                  count: looks.length,
                  selected: filter == _LookFilter.all,
                  onTap: () => onFilter(_LookFilter.all),
                ),
                DsGaps.hXs,
                DsChip(
                  label: l10n.closetLooksFilterReady,
                  icon: Icons.check_circle_outline_rounded,
                  count: ready,
                  selected: filter == _LookFilter.ready,
                  onTap: () => onFilter(_LookFilter.ready),
                ),
                DsGaps.hXs,
                DsChip(
                  label: l10n.closetLooksFilterShort,
                  icon: Icons.add_circle_outline_rounded,
                  count: looks.length - ready,
                  selected: filter == _LookFilter.short,
                  onTap: () => onFilter(_LookFilter.short),
                ),
                if (favourites > 0) ...[
                  DsGaps.hXs,
                  DsChip(
                    label: l10n.closetFilterFavourites,
                    icon: Icons.favorite_border_rounded,
                    count: favourites,
                    selected: filter == _LookFilter.favourites,
                    onTap: () => onFilter(_LookFilter.favourites),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (shown.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: l10n.closetLooksFilterEmpty,
              actionLabel: l10n.closetShowAll,
              onAction: () => onFilter(_LookFilter.all),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.sm,
              DsSpacing.md,
              DsSpacing.xxl,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: DsSpacing.lg,
                crossAxisSpacing: DsSpacing.sm,
                childAspectRatio: 0.64,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final look = shown[index];
                return DsStaggerAnimations.item(
                  index: index,
                  child: ClosetLookTile(
                    look: look,
                    onTap: () => context.push(RoutePaths.closetLookOf(look.id)),
                    onWear: () => onWear(look),
                  ),
                );
              }, childCount: shown.length),
            ),
          ),
      ],
    );
  }
}

/// The book in one sentence and one bar: how much of it she can wear today.
class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.ready, required this.short});

  final int total;
  final int ready;
  final int short;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;

    return CustomerPanel(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        children: [
          Text('$ready', style: text.metric.tint(palette.primary)),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.closetLooksReadyOf(ready, total),
                  style: text.labelStrong,
                ),
                DsGaps.vXxs,
                DsMeter(
                  value: total == 0 ? 0 : ready / total,
                  color: palette.primary,
                  semanticLabel: context.l10n.closetLooksReadyOf(ready, total),
                ),
                if (short > 0) ...[
                  DsGaps.vXxs,
                  Text(
                    context.l10n.closetLooksOneAway(short),
                    style: text.caption.tint(palette.caution),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LooksSkeleton extends StatelessWidget {
  const _LooksSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(DsSpacing.md),
        mainAxisSpacing: DsSpacing.lg,
        crossAxisSpacing: DsSpacing.sm,
        childAspectRatio: 0.64,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 6; i++)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: DsSkeleton.box(height: double.infinity)),
                DsGaps.vXs,
                DsSkeleton.line(width: 100),
                DsGaps.vXxs,
                DsSkeleton.line(width: 64),
              ],
            ),
        ],
      ),
    );
  }
}

