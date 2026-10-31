import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_armoire.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_compartments.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_home_sections.dart';
import 'package:ohara/features/market/presentation/widgets/market_entry_card.dart';

/// خزانتي — the closet's front page.
///
/// The wardrobe itself comes first, drawn as one: she opens the compartment
/// a piece is in, rather than filtering a grid for it. Under it, what she can
/// wear today, the pieces she has forgotten, what the wardrobe is short of,
/// and last the numbers. A shop would invert that and lead with the gaps; a
/// wardrobe that opens with a shopping list is a catalogue that has learned
/// her sizes.
class MyClosetScreen extends ConsumerWidget {
  const MyClosetScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(closetOverviewProvider);
    final l10n = context.l10n;
    final overview = overviewAsync.asData?.value;

    final appBar = PremiumAppBar(
      title: l10n.navCloset,
      subtitle: overview != null && overview.seasonLabel.isNotEmpty
          ? l10n.closetSeasonNow(overview.seasonLabel)
          : null,
      // A tab when she reaches it from the bar, a pushed page when she
      // reaches it from a product: only the second has somewhere to go back.
      showBack: GoRouter.of(context).canPop(),
      actions: [
        if (overview != null && !overview.isEmpty)
          IconButton(
            tooltip: l10n.closetSearchWardrobe,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(
              RoutePaths.closetCompartmentOf(ClosetCompartment.allKey, search: true),
            ),
          ),
        IconButton(
          tooltip: l10n.closetAddPiece,
          icon: const Icon(Icons.add_a_photo_rounded),
          onPressed: () => context.push(RoutePaths.closetAddItem),
        ),
      ],
    );

    return OharaScrollPage(
      onRefresh: () => _refresh(ref),
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
              ? [SliverToBoxAdapter(child: _EmptyCloset(overview: overview))]
              : _content(overview),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  List<Widget> _content(ClosetOverview overview) => [
    DsGaps.sliverMd,
    SliverToBoxAdapter(child: ClosetArmoire(overview: overview)),
    DsGaps.sliverXl,
    SliverToBoxAdapter(child: ClosetQuickActions(overview: overview)),
    DsGaps.sliverXl,
    const SliverToBoxAdapter(child: ClosetTodayPick()),
    if (overview.neglected.isNotEmpty) ...[
      DsGaps.sliverXl,
      SliverToBoxAdapter(child: ClosetRediscoverRail(items: overview.neglected)),
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
    // What her wardrobe can do, in numbers — after the wardrobe, not in
    // front of it.
    DsGaps.sliverXl,
    SliverToBoxAdapter(child: ClosetPulseCard(overview: overview)),
    DsGaps.sliverLg,
    const SliverToBoxAdapter(child: ClosetJourney()),
  ];
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
  const _EmptyCloset({required this.overview});

  final ClosetOverview overview;

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
          // The empty wardrobe itself, every compartment with its "+": the
          // quickest way to fill it is one shelf at a time.
          ClosetArmoire(overview: widget.overview, gutter: 0),
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
