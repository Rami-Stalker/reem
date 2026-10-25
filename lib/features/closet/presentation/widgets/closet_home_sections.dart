import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_gap_card.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_item_tile.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_wear_feedback.dart';
import 'package:ohara/features/closet/presentation/widgets/today_outfit_card.dart';

// ── The pulse ─────────────────────────────────────────────────────────────

/// The header: what her wardrobe can do, not what it cost.
///
/// `outfit_capacity` is the headline rather than the item count, and that is
/// the whole editorial line of the feature: how many outfits her clothes make
/// is a fact about her wardrobe, where how many garments she owns is a fact
/// about her spending.
///
/// The ring beside it is the seasonal story in one shape — the share of her
/// outfits that work in the weather she is actually in. The difference is
/// clothes she owns and cannot wear right now.
class ClosetPulseCard extends StatelessWidget {
  const ClosetPulseCard({super.key, required this.overview});

  final ClosetOverview overview;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;
    final l10n = context.l10n;

    final total = overview.outfitCapacity;
    final seasonal = overview.seasonOutfitCapacity;
    final readiness = total == 0 ? 0.0 : (seasonal / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: palette.signatureGradient,
          borderRadius: DsRadius.borderCard,
          // A soft rose glow rather than the panel shadow: under a saturated
          // gradient the panel shadow reads as a second card behind this one.
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.22),
              blurRadius: DsSpacing.xl,
              offset: const Offset(0, DsSpacing.xs),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: DsRadius.borderCard,
          child: Stack(
            children: [
              // Two soft discs for depth, the same silk the page ground uses.
              PositionedDirectional(
                top: -DsSpacing.huge,
                end: -DsSpacing.xxl,
                child: _Disc(size: DsSizes.avatarHero * 1.6),
              ),
              PositionedDirectional(
                bottom: -DsSpacing.massive,
                start: -DsSpacing.xl,
                child: _Disc(size: DsSizes.avatarHero * 1.4),
              ),
              Padding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.wb_sunny_rounded,
                          size: DsSizes.iconXs,
                          color: DsColors.onMediaMuted,
                        ),
                        DsGaps.hXxs,
                        Expanded(
                          child: Text(
                            l10n.closetPulseEyebrow(overview.seasonLabel),
                            style: text.overline.tint(DsColors.onMediaMuted),
                          ),
                        ),
                        const DsSparkle(size: DsSizes.iconXs),
                      ],
                    ),
                    DsGaps.vSm,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$seasonal',
                                style: text.hero.tint(DsColors.onMedia),
                              ),
                              Text(
                                l10n.closetPulseHeadline,
                                style: text.bodyStrong.tint(DsColors.onMedia),
                              ),
                            ],
                          ),
                        ),
                        if (total > 0) _ReadinessRing(value: readiness),
                      ],
                    ),
                    DsGaps.vSm,
                    Text(
                      _story(context),
                      style: text.caption.tint(DsColors.onMediaMuted),
                    ),
                    DsGaps.vMd,
                    Row(
                      children: [
                        _PulseStat(
                          value: '${overview.itemsCount}',
                          label: l10n.closetMetricPieces,
                        ),
                        DsGaps.hXs,
                        _PulseStat(
                          value: overview.looksCount == 0
                              ? '0'
                              : '${overview.completeLooksCount}/${overview.looksCount}',
                          label: l10n.closetPulseReadyLooks,
                        ),
                        DsGaps.hXs,
                        _PulseStat(
                          value: '${overview.wornThisMonth}',
                          label: l10n.closetMetricWornThisMonth,
                        ),
                      ],
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

  /// The one sentence under the number. Says the uncomfortable thing first:
  /// a closet that cannot dress her this season says which, rather than
  /// congratulating her on the count.
  String _story(BuildContext context) {
    final l10n = context.l10n;
    if (overview.cannotDress) return l10n.closetCannotDressSeason;
    if (overview.outfitCapacity > overview.seasonOutfitCapacity) {
      return l10n.closetSeasonCapacity(
        overview.outfitCapacity,
        overview.seasonOutfitCapacity,
        overview.seasonLabel,
      );
    }
    return l10n.closetPulseAllSeason;
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DsColors.onMedia.withValues(alpha: 0.10),
      ),
    );
  }
}

class _ReadinessRing extends StatelessWidget {
  const _ReadinessRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final percent = (value * 100).round();

    return Semantics(
      label: context.l10n.closetPulseReadiness(percent),
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            width: DsSizes.avatarXl,
            height: DsSizes.avatarXl,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: DsSpacing.xs - DsSpacing.xxxs,
                  strokeCap: StrokeCap.round,
                  color: DsColors.onMedia,
                  backgroundColor: DsColors.onMediaFaint,
                ),
                Center(
                  child: Text(
                    '$percent%',
                    style: text.metricSmall.tint(DsColors.onMedia),
                  ),
                ),
              ],
            ),
          ),
          DsGaps.vXxs,
          Text(
            context.l10n.closetPulseSeasonReady,
            style: text.micro.tint(DsColors.onMediaMuted),
          ),
        ],
      ),
    );
  }
}

class _PulseStat extends StatelessWidget {
  const _PulseStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs,
          vertical: DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: DsColors.onMedia.withValues(alpha: 0.16),
          borderRadius: DsRadius.borderMd,
          border: Border.all(color: DsColors.onMediaFaint),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              style: text.metricSmall.tint(DsColors.onMedia),
            ),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: text.micro.tint(DsColors.onMediaMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The journey ───────────────────────────────────────────────────────────

/// أريد · أفكّر فيها · عندي — one piece's life, read as a path.
///
/// The wishlist, Rooms and the closet used to be three unrelated corners of
/// the app. They are one journey: a piece she wants, then a piece she is
/// deciding on with her friends, then a piece she owns. The closet is the
/// last step and the one this tab shows; the other two are a tap away, and
/// this is the door Rooms kept when it gave its tab to the closet.
class ClosetJourney extends StatelessWidget {
  const ClosetJourney({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _JourneyStep(
              icon: Icons.favorite_border_rounded,
              label: l10n.closetSpectrumWant,
              onTap: () => context.push(RoutePaths.favorites),
            ),
          ),
          const _JourneyLink(),
          Expanded(
            child: _JourneyStep(
              icon: Icons.meeting_room_outlined,
              label: l10n.closetSpectrumDeciding,
              onTap: () => context.push(RoutePaths.rooms),
            ),
          ),
          const _JourneyLink(),
          Expanded(
            child: _JourneyStep(
              icon: Icons.checkroom_rounded,
              label: l10n.closetSpectrumOwn,
              current: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.icon,
    required this.label,
    this.onTap,
    this.current = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The step she is on. Not a link — she is already here — but drawn filled
  /// so the path reads as "you are at the end of it".
  final bool current;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: DsSizes.controlMd,
          height: DsSizes.controlMd,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: current ? palette.signatureGradient : null,
            color: current ? null : palette.surface,
            border: current ? null : Border.all(color: palette.line),
          ),
          child: Icon(
            icon,
            size: DsSizes.iconSm,
            color: current ? DsColors.onMedia : palette.primary,
          ),
        ),
        DsGaps.vXxs,
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: current
              ? text.captionStrong.tint(palette.primary)
              : text.caption.tint(palette.muted),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      selected: current,
      label: label,
      excludeSemantics: true,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              borderRadius: DsRadius.borderMd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
                child: body,
              ),
            ),
    );
  }
}

class _JourneyLink extends StatelessWidget {
  const _JourneyLink();

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.lg),
      child: Icon(
        Icons.arrow_forward_ios_rounded,
        size: DsSizes.iconXxs,
        color: palette.muted.withValues(alpha: 0.6),
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────

/// The four ways out of the front page, as labelled tiles.
///
/// They were four bare icons in the app bar — a sun, a sparkle, a camera and
/// a party popper — which she had to long-press to learn the names of.
class ClosetQuickActions extends StatelessWidget {
  const ClosetQuickActions({super.key, required this.overview});

  final ClosetOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionTile(
              icon: Icons.wb_twilight_rounded,
              label: l10n.closetActionToday,
              tone: DsTone.accent,
              onTap: () => context.push(RoutePaths.closetToday),
            ),
            DsGaps.hXs,
            _ActionTile(
              icon: Icons.auto_awesome_mosaic_rounded,
              label: l10n.closetMyLooks,
              count: overview.looksCount,
              tone: DsTone.critical,
              onTap: () => context.push(RoutePaths.closetLooks),
            ),
            DsGaps.hXs,
            _ActionTile(
              icon: Icons.add_a_photo_rounded,
              label: l10n.closetActionAdd,
              tone: DsTone.info,
              onTap: () => context.push(RoutePaths.closetAddItem),
            ),
            DsGaps.hXs,
            _ActionTile(
              icon: Icons.celebration_rounded,
              label: l10n.actionOccasions,
              tone: DsTone.positive,
              onTap: () => context.push(RoutePaths.occasions),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final DsTone tone;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;

    return Expanded(
      child: Semantics(
        button: true,
        label: count == null ? label : '$label ($count)',
        excludeSemantics: true,
        child: Material(
          color: palette.surface,
          borderRadius: DsRadius.borderLg,
          child: InkWell(
            onTap: onTap,
            borderRadius: DsRadius.borderLg,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.xxs,
                vertical: DsSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderLg,
                border: Border.all(color: palette.line.withValues(alpha: 0.7)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Badge(
                    isLabelVisible: count != null && count! > 0,
                    label: Text('${count ?? 0}'),
                    backgroundColor: context.toneColor(tone),
                    textColor: DsColors.onMedia,
                    child: Container(
                      padding: const EdgeInsets.all(DsSpacing.xs),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.toneContainer(tone),
                      ),
                      child: Icon(
                        icon,
                        size: DsSizes.iconSm,
                        color: context.toneColor(tone),
                      ),
                    ),
                  ),
                  DsGaps.vXs,
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: text.captionStrong.tint(palette.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Today's pick ──────────────────────────────────────────────────────────

/// The first answer to "شو بقدر ألبس اليوم؟", on the front page.
///
/// The question is the reason most women open a wardrobe at all, so the
/// answer should not be a tap away. Renders nothing when there is no answer
/// or the request fails — the full screen explains an empty answer; the
/// front page has no room to.
class ClosetTodayPick extends ConsumerStatefulWidget {
  const ClosetTodayPick({super.key});

  @override
  ConsumerState<ClosetTodayPick> createState() => _ClosetTodayPickState();
}

class _ClosetTodayPickState extends ConsumerState<ClosetTodayPick> {
  final _worn = <String>{};

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayOutfitsProvider(null));
    final l10n = context.l10n;

    return todayAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(child: DsSkeleton.box(height: DsSizes.avatarHero * 3)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (today) {
        if (today.outfits.isEmpty) return const SizedBox.shrink();
        final outfit = today.outfits.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClosetSectionHeading(
              eyebrow: l10n.closetTodayEyebrow,
              title: l10n.closetWhatToWearToday,
              actionLabel: today.outfits.length > 1
                  ? l10n.closetMoreIdeas(today.outfits.length - 1)
                  : null,
              onAction: () => context.push(RoutePaths.closetToday),
            ),
            DsGaps.vSm,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
              child: TodayOutfitCard(
                outfit: outfit,
                worn: _worn.contains(outfit.key),
                onWear: () async {
                  final ok = await logTodayOutfitWear(context, ref, outfit);
                  if (ok && mounted) setState(() => _worn.add(outfit.key));
                },
                onOpenLook: outfit.lookId == null
                    ? null
                    : () => context.push(RoutePaths.closetLookOf(outfit.lookId!)),
                onSaveAsLook: outfit.isSaved
                    ? null
                    : () => saveTodayOutfitAsLook(context, ref, outfit),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Rails ─────────────────────────────────────────────────────────────────

/// A horizontal rail's height, grown with her text size.
///
/// A horizontal list needs a fixed cross-axis extent, and a fixed number is
/// the classic way a rail clips its own captions at 160% text. The fixed part
/// (photo, padding) stays fixed; only the part made of text is scaled.
double closetRailHeight(BuildContext context, {required double fixed, required double text}) =>
    fixed + MediaQuery.textScalerOf(context).scale(text);

/// «قطع تنتظركِ» — the pieces she owns and has stopped reaching for.
///
/// The server already sends them with the overview, never worn first; this
/// is the first screen to show them. Each has the one-tap wear on it, because
/// the cure for a forgotten dress is wearing it, not reading about it.
class ClosetRediscoverRail extends ConsumerWidget {
  const ClosetRediscoverRail({super.key, required this.items});

  final List<ClosetItem> items;

  static const double _tileWidth = DsSizes.railCardWidth * 0.75;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClosetSectionHeading(
          eyebrow: l10n.closetRediscoverEyebrow,
          title: l10n.closetRediscoverTitle,
        ),
        DsGaps.vXxs,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: Text(l10n.closetRediscoverBody, style: context.dsText.caption),
        ),
        DsGaps.vSm,
        SizedBox(
          height: closetRailHeight(
            context,
            fixed: _tileWidth / 0.75 + DsSpacing.xs,
            text: DsSpacing.xxxl,
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => DsGaps.hSm,
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: _tileWidth,
                child: ClosetItemTile(
                  item: item,
                  dense: true,
                  onTap: () => context.push(RoutePaths.closetItemOf(item.id)),
                  onWear: () => logClosetWear(context, ref, item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// «ما ينقص خزانتكِ» — the gaps, as a rail of compact cards.
class ClosetGapRail extends StatelessWidget {
  const ClosetGapRail({super.key, required this.gaps});

  final List<ClosetGap> gaps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClosetSectionHeading(
          eyebrow: l10n.closetGapsEyebrow,
          title: l10n.closetWhatsMissing,
        ),
        DsGaps.vSm,
        SizedBox(
          height: closetRailHeight(
            context,
            fixed: DsSpacing.massive + DsSpacing.xl,
            text: DsSizes.railCardWidth * 0.8,
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              0,
              DsSpacing.lg,
              DsSpacing.sm,
            ),
            itemCount: gaps.length,
            separatorBuilder: (_, _) => DsGaps.hSm,
            itemBuilder: (context, index) {
              final gap = gaps[index];
              return SizedBox(
                width: DsSizes.railCardWidth * 1.65,
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
