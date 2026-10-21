import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';
import 'package:reem/features/trends/presentation/widgets/trend_pieces.dart';
import 'package:reem/features/trends/presentation/widgets/trend_text_action.dart';

// ── Insight card ─────────────────────────────────────────────────────────

/// One recommended action.
///
/// The card can be unfolded into the numbers it was computed from. That
/// affordance is the whole reason a seller should be willing to act on a
/// sentence a machine wrote: the sentence is a rendering of arithmetic, and
/// the arithmetic is one tap away rather than in a log file.
class TrendInsightCard extends StatefulWidget {
  const TrendInsightCard({
    super.key,
    required this.insight,
    this.onAcknowledge,
    this.onDismiss,
    this.isBusy = false,
  });

  final TrendInsight insight;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onDismiss;
  final bool isBusy;

  @override
  State<TrendInsightCard> createState() => _TrendInsightCardState();
}

class _TrendInsightCardState extends State<TrendInsightCard> {
  bool _showEvidence = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final insight = widget.insight;
    final colour = severityColour(context, insight.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A severity rail down the leading edge, so a feed can be
            // triaged by colour without reading a word of it.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: colour),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(DsSpacing.xs),
                                decoration: BoxDecoration(
                                  color: colour.withValues(alpha: 0.14),
                                  borderRadius: DsRadius.borderSm,
                                ),
                                child: Icon(
                                  insightIcon(insight.kind),
                                  size: 16,
                                  color: colour,
                                ),
                              ),
                              const SizedBox(width: DsSpacing.sm),
                              Expanded(
                                child: Text(
                                  insight.titleAr,
                                  style: context.dsText.body.bold.tint(palette.ink),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DsSpacing.sm),
                          Text(
                            insight.bodyAr,
                            style: context.dsText.bodySmall.tint(palette.ink).copyWith(height: 1.6),
                          ),

                          if (insight.actionAr != null) ...[
                            const SizedBox(height: DsSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(DsSpacing.sm),
                              decoration: BoxDecoration(
                                color: palette.primarySoft,
                                borderRadius: DsRadius.borderSm,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 15,
                                    color: palette.primary,
                                  ),
                                  const SizedBox(width: DsSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      insight.actionAr!,
                                      style: context.dsText.labelMedium.tint(palette.primary).copyWith(height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_showEvidence && insight.metrics.isNotEmpty) ...[
                            const SizedBox(height: DsSpacing.sm),
                            _Evidence(metrics: insight.metrics),
                          ],

                          const SizedBox(height: DsSpacing.sm),
                          Row(
                            children: [
                              if (insight.metrics.isNotEmpty)
                                TrendTextAction(
                                  label: _showEvidence
                                      ? l10n.trendHideEvidence
                                      : l10n.trendShowEvidence,
                                  icon: _showEvidence
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  onTap: () => setState(
                                    () => _showEvidence = !_showEvidence,
                                  ),
                                ),
                              const Spacer(),
                              if (widget.isBusy)
                                DsLoadingIndicator.inline(color: palette.primary)
                              else ...[
                                if (widget.onDismiss != null)
                                  TrendTextAction(
                                    label: l10n.trendDismiss,
                                    icon: Icons.close_rounded,
                                    tone: palette.muted,
                                    onTap: widget.onDismiss!,
                                  ),
                                if (widget.onAcknowledge != null) ...[
                                  const SizedBox(width: DsSpacing.sm),
                                  TrendTextAction(
                                    label: l10n.trendMarkDone,
                                    icon: Icons.check_rounded,
                                    tone: palette.positive,
                                    onTap: widget.onAcknowledge!,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The numbers under the sentence.
///
/// Rendered from whatever keys the finding happens to carry rather than from a
/// fixed list, so a new rule on the server needs no client release to be
/// explainable. The keys are snake_case identifiers; they are shown as-is
/// because inventing Arabic for an unknown key would be worse than showing the
/// key somebody can search the source for.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.metrics});

  final Map<String, dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final entries = metrics.entries
        .where((entry) => entry.value != null && entry.key != 'window_days')
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: palette.line),
      ),
      // The keys are English identifiers and the values are figures, so this
      // one panel reads left to right inside an otherwise right-to-left page.
      // Laid out RTL, the label and its value end up adjacent and touching —
      // «42.28score» — which is unreadable in either language.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxxs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key.replaceAll('_', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    Text(
                      _format(entry.value),
                      style: context.dsText.caption.semibold.tint(palette.ink),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _format(dynamic value) => switch (value) {
    final num v when v == v.roundToDouble() => formatCount(v),
    final num v => v.toStringAsFixed(2),
    final bool v => v ? '✓' : '✗',
    _ => value.toString(),
  };
}
