import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_wear_feedback.dart';
import 'package:ohara/features/closet/presentation/widgets/today_outfit_card.dart';

/// شو بقدر ألبس اليوم؟
///
/// Answers from her own clothes. Nothing on this screen is for sale, and the
/// only mention of the shop is when an outfit is genuinely one piece short —
/// which is the difference between a wardrobe assistant and an advert wearing
/// one's clothes.
class ClosetTodayScreen extends ConsumerStatefulWidget {
  const ClosetTodayScreen({super.key});

  @override
  ConsumerState<ClosetTodayScreen> createState() => _ClosetTodayScreenState();
}

class _ClosetTodayScreenState extends ConsumerState<ClosetTodayScreen> {
  String? _occasion;

  /// Outfits she has logged on this visit. Kept so a worn card says so rather
  /// than offering the button again.
  final _worn = <String>{};

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final todayAsync = ref.watch(todayOutfitsProvider(_occasion));
    final overview = ref.watch(closetOverviewProvider).asData?.value;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(
        title: l10n.closetWhatToWearToday,
        actions: [
          IconButton(
            tooltip: l10n.closetMyLooks,
            icon: const Icon(Icons.auto_awesome_mosaic_rounded),
            onPressed: () => context.push(RoutePaths.closetLooks),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todayOutfitsProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Greeting(overview: overview)),
            if (overview != null)
              SliverToBoxAdapter(
                child: _OccasionFilter(
                  occasions: overview.vocabulary.occasions,
                  selected: _occasion,
                  onSelected: (value) => setState(() => _occasion = value),
                ),
              ),
            ...todayAsync.when(
              loading: () => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(DsSpacing.lg),
                    child: DsShimmer(
                      child: Column(
                        children: [
                          DsSkeleton.box(height: DsSizes.railCardHeight * 1.4),
                          DsGaps.vMd,
                          DsSkeleton.box(height: DsSizes.railCardHeight),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              error: (_, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: DsErrorState(
                    message: l10n.closetTodayFailed,
                    onRetry: () => ref.invalidate(todayOutfitsProvider),
                  ),
                ),
              ],
              data: (today) => today.outfits.isEmpty
                  ? [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NothingToWear(
                          occasion: _occasion,
                          onClear: () => setState(() => _occasion = null),
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          DsSpacing.lg,
                          DsSpacing.xs,
                          DsSpacing.lg,
                          DsSpacing.xxl,
                        ),
                        sliver: SliverList.separated(
                          itemCount: today.outfits.length,
                          separatorBuilder: (_, _) => DsGaps.vMd,
                          itemBuilder: (context, index) {
                            final outfit = today.outfits[index];
                            return DsStaggerAnimations.item(
                              index: index,
                              child: TodayOutfitCard(
                                outfit: outfit,
                                featured: index == 0,
                                eyebrow: index == 0
                                    ? l10n.closetTodayBestMatch
                                    : l10n.closetTodayIdea(index + 1),
                                worn: _worn.contains(outfit.key),
                                onWear: () => _wear(outfit),
                                onOpenLook: outfit.lookId == null
                                    ? null
                                    : () => context.push(
                                        RoutePaths.closetLookOf(outfit.lookId!),
                                      ),
                                onSaveAsLook: outfit.isSaved
                                    ? null
                                    : () => saveTodayOutfitAsLook(
                                        context,
                                        ref,
                                        outfit,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _wear(TodayOutfit outfit) async {
    final ok = await logTodayOutfitWear(context, ref, outfit);
    if (ok && mounted) setState(() => _worn.add(outfit.key));
  }
}

/// A line of context above the answers: the day and the weather the picker
/// reasoned about, so a summer dress in the list is never a mystery.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.overview});

  final ClosetOverview? overview;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;
    final season = overview?.seasonLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DsSpacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: palette.signatureGradient,
            ),
            child: const Icon(
              Icons.wb_twilight_rounded,
              color: DsColors.onMedia,
              size: DsSizes.iconSm,
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.closetTodayHello, style: text.cardTitle),
                Text(
                  season == null || season.isEmpty
                      ? context.l10n.closetTodayFromYours
                      : context.l10n.closetTodaySeason(season),
                  style: text.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OccasionFilter extends StatelessWidget {
  const _OccasionFilter({
    required this.occasions,
    required this.selected,
    required this.onSelected,
  });

  final List<ClosetTerm> occasions;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DsSizes.controlLg,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.xxs,
        ),
        children: [
          DsChip(
            label: context.l10n.closetAnyOccasion,
            icon: Icons.all_inclusive_rounded,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final occasion in occasions) ...[
            DsGaps.hXs,
            DsChip(
              label: occasion.label,
              selected: selected == occasion.key,
              onTap: () => onSelected(occasion.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _NothingToWear extends StatelessWidget {
  const _NothingToWear({required this.occasion, required this.onClear});

  final String? occasion;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsEmptyState(
      icon: Icons.checkroom_rounded,
      title: occasion == null ? l10n.closetCannotDress : l10n.closetNothingForOccasion,
      // Says which shortage caused it rather than "no results": the picker only
      // fails when a whole slot is empty, and naming it is the difference
      // between advice and a shrug.
      message: occasion == null
          ? l10n.closetCannotDressBody
          : l10n.closetNothingForOccasionBody,
      actionLabel: occasion == null ? l10n.closetAddPiece : l10n.closetAnyOccasion,
      onAction: occasion == null
          ? () => context.push(RoutePaths.closetAddItem)
          : onClear,
    );
  }
}
