import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/seller_analytics/domain/entities/seller_analytics_report.dart';

/// A section title with a rule under it, so the page reads as chapters rather
/// than one long column of numbers.
class AnalyticsSectionHeader extends StatelessWidget {
  const AnalyticsSectionHeader(this.title, {super.key, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        atelierGutter(context),
        DsSpacing.xxl,
        atelierGutter(context),
        DsSpacing.md,
      ),
      child: AtelierHeading(title: title, caption: hint),
    );
  }
}

class AnalyticsMetricTile extends StatelessWidget {
  const AnalyticsMetricTile({
    super.key,
    required this.label,
    this.value,
    this.amounts,
    this.hint,
    this.tone,
  });

  final String label;
  final String? value;
  final MoneyTotals? amounts;
  final String? hint;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final money = amounts ?? const <Money>[];

    // A figure keyed on its leading edge in its own colour — champagne for
    // the plain ones — like a label stitched to a seam.
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderLg,
        border: BorderDirectional(
          start: BorderSide(color: tone ?? palette.gold, width: DsSpacing.xxs),
        ),
        boxShadow: palette.shadow,
      ),
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
          // Figures shrink to fit rather than truncate. An SYP total is nine
          // digits and a symbol; ellipsised, «131,000,000 ل.س» became
          // «131,000,000 ل....» — a seller unable to read her own revenue.
          if (value != null)
            _Figure(
              text: value!,
              size: DsTypography.titleMedium,
              color: tone ?? palette.ink,
            )
          else if (money.isEmpty)
            _Figure(
              text: '—',
              size: DsTypography.titleMedium,
              color: palette.muted,
            )
          else
            for (final amount in money)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.xxxs),
                child: _Figure(
                  text: amount.format(),
                  size: DsTypography.titleSmall,
                  color: tone ?? palette.ink,
                ),
              ),
          if (hint != null) ...[
            DsGaps.vXxxs,
            Text(hint!, style: context.dsText.caption.tint(palette.muted)),
          ],
        ],
      ),
    );
  }
}

/// One figure, scaled down rather than cut off.
class _Figure extends StatelessWidget {
  const _Figure({required this.text, required this.size, required this.color});

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: context.dsText.labelStrong.bold.displayFamily
            .tint(color)
            .copyWith(fontSize: size * 1.15),
      ),
    );
  }
}

/// A responsive grid of metric tiles — two across on a phone, four on a desk.
///
/// Laid out as explicit rows rather than a [Wrap] so neighbours share a height.
/// One tile carrying a hint line under it made the whole run ragged, which
/// reads as a rendering fault rather than a design.
class AnalyticsMetricGrid extends StatelessWidget {
  const AnalyticsMetricGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 560
              ? 3
              : 2;

          final rows = <List<Widget>>[];
          for (var i = 0; i < tiles.length; i += columns) {
            rows.add(tiles.sublist(i, (i + columns).clamp(0, tiles.length)));
          }

          return Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) DsGaps.vMd,
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) DsGaps.hMd,
                        // A short final row keeps the column rhythm rather
                        // than stretching two tiles across four columns.
                        Expanded(
                          child: c < rows[r].length
                              ? rows[r][c]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The path from a product view to a placed order, drawn as proportional bars.
///
/// A funnel is the one chart here that has to be read as *ratios*: the useful
/// question is not how many people added to a cart but how many of the people
/// who looked did. So every bar is measured against the widest step, and the
/// drop between two steps is the thing the eye lands on.
class AnalyticsFunnel extends StatelessWidget {
  const AnalyticsFunnel({super.key, required this.steps, required this.labels});

  final List<FunnelStep> steps;

  /// The server names the steps in English; the seller reads Arabic. The
  /// screen supplies the translation rather than the API guessing a locale.
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final widest = steps.isEmpty
        ? 0
        : steps.map((s) => s.count).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
      child: SellerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: DsSpacing.md),
              _Bar(
                label: i < labels.length ? labels[i] : steps[i].step,
                count: steps[i].count,
                fraction: widest == 0 ? 0 : steps[i].count / widest,
                color: palette.series[i % palette.series.length],
                // The share of the step above it — the number she can act on.
                carriedOver: i == 0 || steps[i - 1].count == 0
                    ? null
                    : steps[i].count / steps[i - 1].count,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
    this.carriedOver,
  });

  final String label;
  final int count;
  final double fraction;
  final Color color;
  final double? carriedOver;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.labelMedium.tint(palette.ink),
              ),
            ),
            if (carriedOver != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: DsSpacing.sm),
                child: Text(
                  '${(carriedOver! * 100).round()}%',
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ),
            Text(
              '$count',
              style: context.dsText.labelMedium.bold.tint(palette.ink),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xs),
        // Each step a length of tape, as far as the orders carried.
        TapeMeasure(
          value: fraction.clamp(0.0, 1.0),
          max: 1,
          color: color,
          height: DsSpacing.md,
        ),
      ],
    );
  }
}

/// The best sellers, as a plain ranked list. A pie chart of twenty products is
/// unreadable; a list sorted by units is what she would write out herself.
class AnalyticsProductTable extends StatelessWidget {
  const AnalyticsProductTable({super.key, required this.rows});

  final List<ProductPerformanceRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
      child: SellerPanel(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: DsSpacing.xl, color: palette.line),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.md,
                  vertical: DsSpacing.sm,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: DsSizes.controlSm,
                      child: Text(
                        '${i + 1}',
                        style: context.dsText.metricSmall.displayFamily.tint(
                          i == 0 ? palette.gold : palette.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.body.medium.tint(palette.ink),
                          ),
                          Text(
                            l10n.analyticsUnitsSold(rows[i].units),
                            style: context.dsText.caption.tint(palette.muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final amount in rows[i].revenue)
                          Text(
                            amount.format(),
                            style: context.dsText.labelMedium.bold.tint(
                              palette.ink,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
