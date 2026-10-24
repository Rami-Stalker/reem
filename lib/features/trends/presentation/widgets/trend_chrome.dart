import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';
import 'package:ohara/features/trends/presentation/widgets/trend_palette.dart';

/// The furniture every trend page is built out of: section headers,
/// stage chips, signed deltas, metric tiles, and the window selector.

// ── Section header ───────────────────────────────────────────────────────

class TrendSectionHeader extends StatelessWidget {
  const TrendSectionHeader(this.title, {super.key, this.hint, this.trailing});

  final String title;
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.xl,
        DsSpacing.lg,
        DsSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.dsText.cardTitle.displayFamily.bold.tint(palette.ink),
                ),
                if (hint != null) ...[
                  DsGaps.vXxxs,
                  Text(
                    hint!,
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ── Chips and deltas ─────────────────────────────────────────────────────

class TrendStageChip extends StatelessWidget {
  const TrendStageChip(this.stage, {super.key, this.compact = false});

  final TrendStageLabel stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colour = stageColour(context, stage.stage);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DsSpacing.xs : DsSpacing.sm,
        vertical: compact ? DsSpacing.xxxs : DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: DsRadius.borderSm,
      ),
      child: Text(
        stage.labelAr,
        style: (compact
                ? context.dsText.caption.semibold
                : context.dsText.labelStrong)
            .tint(colour),
      ),
    );
  }
}

/// A signed change, with the arrow the sign implies.
///
/// [invert] is for the figures where down is good — a cancellation rate, a
/// return rate. Without it a falling return rate would be painted red, which
/// is precisely backwards.
class TrendDelta extends StatelessWidget {
  const TrendDelta({
    super.key,
    required this.value,
    this.suffix = '',
    this.invert = false,
    this.fontSize,
  });

  final double value;
  final String suffix;
  final bool invert;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final flat = value.abs() < 0.05;
    final good = invert ? value < 0 : value > 0;
    final colour = flat
        ? palette.muted
        : (good ? palette.positive : palette.critical);
    final icon = flat
        ? Icons.remove_rounded
        : (value > 0
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: (fontSize ?? DsTypography.labelMedium) + 2,
          color: colour,
        ),
        DsGaps.hXxxs,
        Text(
          '${value.abs() < 10 ? value.abs().toStringAsFixed(1) : value.abs().round()}$suffix',
          style: context.dsText.labelStrong.tint(colour).copyWith(fontSize: fontSize),
        ),
      ],
    );
  }
}

// ── Metric tile ──────────────────────────────────────────────────────────

class TrendMetricTile extends StatelessWidget {
  const TrendMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaSuffix = '%',
    this.invertDelta = false,
    this.tone,
    this.hint,
  });

  final String label;
  final String value;
  final double? delta;
  final String deltaSuffix;
  final bool invertDelta;
  final Color? tone;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SellerPanel(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption.tint(palette.muted),
          ),
          const SizedBox(height: DsSpacing.xs),
          // Figures shrink to fit rather than truncate: an SYP total is nine
          // digits and a symbol, and «131,000,000 ل....» is a number nobody
          // can read.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: context.dsText.cardTitle.displayFamily.bold.tint(tone ?? palette.ink),
            ),
          ),
          if (delta != null) ...[
            DsGaps.vXxxs,
            TrendDelta(
              value: delta!,
              suffix: deltaSuffix,
              invert: invertDelta,
              fontSize: DsTypography.labelSmall,
            ),
          ],
          if (hint != null) ...[
            DsGaps.vXxxs,
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.caption.tint(palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class TrendMetricGrid extends StatelessWidget {
  const TrendMetricGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two per row on a phone, three once there is room. Fixed columns
          // rather than a wrap, so the tiles keep a shared baseline.
          final columns = constraints.maxWidth >= 560 ? 3 : 2;
          const gap = DsSpacing.sm;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles) SizedBox(width: width, child: tile),
            ],
          );
        },
      ),
    );
  }
}

// ── Window selector ──────────────────────────────────────────────────────

class TrendWindowBar extends StatelessWidget {
  const TrendWindowBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final TrendWindow selected;
  final ValueChanged<TrendWindow> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    String label(TrendWindow window) => switch (window) {
      TrendWindow.d7 => l10n.trendWindow7,
      TrendWindow.d14 => l10n.trendWindow14,
      TrendWindow.d30 => l10n.trendWindow30,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.xxxs,
      ),
      child: Row(
        children: [
          for (final window in TrendWindow.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: DsSpacing.xs),
                child: _WindowButton(
                  label: label(window),
                  isSelected: window == selected,
                  onTap: () => onSelect(window),
                  palette: palette,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final SellerAtelierPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? palette.primary : palette.surface,
      borderRadius: DsRadius.borderMd,
      child: InkWell(
        borderRadius: DsRadius.borderMd,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderMd,
            border: Border.all(
              color: isSelected ? palette.primary : palette.line,
            ),
          ),
          child: Text(
            label,
            style: context.dsText.labelMedium.semibold.tint(isSelected ? palette.onPrimary : palette.muted),
          ),
        ),
      ),
    );
  }
}
