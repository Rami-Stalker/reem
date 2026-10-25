import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// One thing her wardrobe is short of.
///
/// The card shows the headline, the reason, how much it matters, and a way to
/// see the arithmetic. That last part is not decoration: this feature holds a
/// list of a woman's clothes and tells her what to buy, and the least it can
/// do is let her open the reasoning. A recommendation she cannot interrogate
/// is one she has to take on trust.
class ClosetGapCard extends StatelessWidget {
  const ClosetGapCard({
    super.key,
    required this.gap,
    this.onTap,
    this.onDismiss,
    this.compact = false,
  });

  final ClosetGap gap;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  /// The horizontal-rail form used on the closet's front page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final tone = closetGapTone(gap.kind);
    final unlocked = gap.outfitsUnlocked;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      semanticLabel: gap.headline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DsSpacing.xs),
                decoration: BoxDecoration(
                  color: context.toneContainer(tone),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  closetGapIcon(gap.kind),
                  size: DsSizes.iconXs,
                  color: context.toneColor(tone),
                ),
              ),
              DsGaps.hXs,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      closetGapKindLabel(context.l10n, gap.kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.overline.tint(context.toneColor(tone)),
                    ),
                    Text(
                      gap.slotLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelStrong,
                    ),
                  ],
                ),
              ),
              if (unlocked != null && unlocked > 0)
                ClosetPill(
                  label: context.l10n.closetGapUnlocks(unlocked),
                  icon: Icons.add_rounded,
                  tone: DsTone.positive,
                ),
              if (onDismiss != null && !compact)
                IconButton(
                  tooltip: context.l10n.closetNotInterested,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    size: DsSizes.iconXs,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          DsGaps.vSm,
          Text(
            gap.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.cardTitle,
          ),
          DsGaps.vXxs,
          Text(
            gap.rationale,
            maxLines: compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: text.cardSubtitle,
          ),
          DsGaps.vSm,
          // How much it matters, as a bar rather than a number: the number is
          // one tap away in the reasoning sheet, and a "73" on a card reads as
          // a score she is being graded on.
          Row(
            children: [
              Text(context.l10n.closetPriority, style: text.micro),
              DsGaps.hXs,
              Expanded(
                child: DsMeter(
                  value: (gap.priority / 100).clamp(0, 1).toDouble(),
                  weight: DsMeterWeight.thin,
                  color: context.toneColor(tone),
                  semanticLabel: context.l10n.closetPriority,
                ),
              ),
            ],
          ),
          if (!compact && _hasConstraints) ...[
            DsGaps.vSm,
            Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                // The constraints, shown because they are the promise: a
                // suggestion arriving against this gap will be in these colours
                // and this size, and she can see that before she taps.
                for (final colour in gap.suggestedColours.take(3))
                  ClosetPill(label: colour.label, icon: Icons.palette_rounded),
                if (gap.suggestedSize != null)
                  ClosetPill(
                    label: context.l10n.closetSizeValue(gap.suggestedSize!),
                    icon: Icons.straighten_rounded,
                  ),
                if (_budget(context) case final budget?)
                  ClosetPill(
                    label: budget,
                    icon: Icons.savings_rounded,
                    tone: DsTone.accent,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasConstraints =>
      gap.suggestedColours.isNotEmpty ||
      gap.suggestedSize != null ||
      gap.suggestedBudgetMax != null;

  String? _budget(BuildContext context) {
    final min = gap.suggestedBudgetMin;
    final max = gap.suggestedBudgetMax;
    if (max == null) return null;
    if (min == null) return context.l10n.closetBudgetUpTo(max.format());
    return context.l10n.closetBudgetRange(min.format(), max.format());
  }
}

IconData closetGapIcon(ClosetGapKind kind) => switch (kind) {
  ClosetGapKind.lookSlot => Icons.auto_awesome_rounded,
  ClosetGapKind.occasion => Icons.celebration_rounded,
  ClosetGapKind.coverage => Icons.grid_view_rounded,
  ClosetGapKind.season => Icons.wb_sunny_rounded,
  ClosetGapKind.replacement => Icons.autorenew_rounded,
};

/// What a gap means, as a tone. A gap that finishes a look she has already
/// chosen is the warmest thing on the list; a replacement is the coolest.
DsTone closetGapTone(ClosetGapKind kind) => switch (kind) {
  ClosetGapKind.lookSlot => DsTone.accent,
  ClosetGapKind.occasion => DsTone.accent,
  ClosetGapKind.coverage => DsTone.info,
  ClosetGapKind.season => DsTone.caution,
  ClosetGapKind.replacement => DsTone.neutral,
};

String closetGapKindLabel(AppLocalizations l10n, ClosetGapKind kind) =>
    switch (kind) {
      ClosetGapKind.lookSlot => l10n.closetGapKindLook,
      ClosetGapKind.occasion => l10n.closetGapKindOccasion,
      ClosetGapKind.coverage => l10n.closetGapKindCoverage,
      ClosetGapKind.season => l10n.closetGapKindSeason,
      ClosetGapKind.replacement => l10n.closetGapKindReplacement,
    };

/// The arithmetic behind a gap, as a sheet.
///
/// Renders `components` verbatim. Deliberately unglamorous — it is a receipt,
/// not a feature — and it is the reason the engine stores its breakdown beside
/// every priority it writes.
class GapReasoningSheet extends StatelessWidget {
  const GapReasoningSheet({super.key, required this.gap});

  final ClosetGap gap;

  /// The server's component keys, in her words. A key the app does not know
  /// yet is shown as sent rather than hidden: the sheet exists so every
  /// number can be taken apart, and dropping a row would break that.
  static String _label(AppLocalizations l10n, String key) => switch (key) {
    'base' => l10n.closetReasonBase,
    'nearly_complete' => l10n.closetReasonNearlyComplete,
    'favourite_look' => l10n.closetReasonFavouriteLook,
    'core_slot' => l10n.closetReasonCoreSlot,
    'already_chosen' => l10n.closetReasonAlreadyChosen,
    'season_fit' => l10n.closetReasonSeasonFit,
    'interest' => l10n.closetReasonInterest,
    'anchor_slot' => l10n.closetReasonAnchorSlot,
    'owns_nothing' => l10n.closetReasonOwnsNone,
    'outfit_gain' => l10n.closetReasonOutfitGain,
    'owns_none' => l10n.closetReasonOwnsNone,
    'unlocks_first_outfit' => l10n.closetReasonFirstOutfit,
    'outfits_unlocked' => l10n.closetReasonOutfitsUnlocked,
    'outfits_now' => l10n.closetReasonOutfitsNow,
    'shelved' => l10n.closetReasonShelved,
    'owned_out_of_season' => l10n.closetReasonOutOfSeason,
    'wear' => l10n.closetReasonWear,
    'sole_in_slot' => l10n.closetReasonSoleInSlot,
    'wear_count' => l10n.closetReasonWearCount,
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final tone = closetGapTone(gap.kind);
    final entries = gap.components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final largest = entries.fold<num>(
      0,
      (max, entry) => entry.value.abs() > max ? entry.value.abs() : max,
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: DsSpacing.sheetPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: DsSizes.iconSm,
                  color: context.toneColor(tone),
                ),
                DsGaps.hXs,
                Expanded(
                  child: Text(
                    context.l10n.closetWhyWeSuggest,
                    style: text.sectionTitle,
                  ),
                ),
              ],
            ),
            DsGaps.vXs,
            Text(gap.rationale, style: text.bodyMuted),
            DsGaps.vMd,
            // Every component, largest first, each with its share of the
            // largest — a receipt she can read at a glance, not a table she
            // has to add up.
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _label(context.l10n, entry.key),
                            style: text.body,
                          ),
                        ),
                        Text(
                          _format(entry.value),
                          style: text.numeric.tint(colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                    DsGaps.vXxs,
                    DsMeter(
                      value: largest == 0
                          ? 0
                          : (entry.value.abs() / largest).toDouble(),
                      weight: DsMeterWeight.thin,
                      color: context.toneColor(tone).withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            const Divider(height: DsSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.closetPriority,
                    style: text.labelStrong,
                  ),
                ),
                Text(
                  context.l10n.closetPriorityOutOf(
                    gap.priority.toStringAsFixed(0),
                  ),
                  style: text.metricSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _format(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}
