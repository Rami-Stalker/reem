import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:ohara/features/reputation/presentation/widgets/fit_labels.dart';

/// «المقاس حسب اللي لبسوه» — how a piece fits, from its reviews.
///
/// Two halves. Everyone sees the overall tally. A woman who has said her size
/// also sees the tally among women like her and, when enough of them agree,
/// the size they kept. Below the server's floor the counts are shown as
/// counts and no verdict is drawn: two women are two women, not "runs small".
///
/// Draws nothing at all for a piece nobody has said anything about, rather
/// than an empty box that reads as a broken feature.
class ProductFitPanel extends ConsumerWidget {
  const ProductFitPanel({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(productFitProvider(productId)).asData?.value;
    if (fit == null || fit.overall.total == 0) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colors = context.dsColors;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.straighten_rounded,
                size: DsSizes.iconMd,
                color: colors.primary,
              ),
              DsGaps.hXs,
              Expanded(
                child: Text(
                  l10n.fitPanelTitle,
                  style: context.dsText.bodyStrong,
                ),
              ),
            ],
          ),
          DsGaps.vSm,
          _TallyLine(
            tally: fit.overall,
            heading: l10n.fitEveryone(fit.overall.total),
          ),
          if (fit.hasProfile) ...[
            DsGaps.vSm,
            if (fit.nearMe != null && fit.nearMe!.total > 0)
              _TallyLine(
                tally: fit.nearMe!,
                heading: l10n.fitLikeYou(fit.nearMe!.total),
              )
            else
              Text(
                l10n.fitLikeYouNone,
                style: context.dsText.caption.tint(colors.onSurfaceVariant),
              ),
            if (fit.suggestedSize != null) ...[
              DsGaps.vXs,
              Row(
                children: [
                  Icon(
                    Icons.recommend_rounded,
                    size: DsSizes.iconSm,
                    color: colors.success,
                  ),
                  DsGaps.hXxs,
                  Expanded(
                    child: Text(
                      l10n.fitSuggestedSize(fit.suggestedSize!),
                      style: context.dsText.caption.semibold.tint(
                        colors.successInk,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            DsGaps.vXs,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => context.push(RoutePaths.fitProfile),
                icon: const Icon(Icons.person_search_rounded),
                label: Text(l10n.fitSeeLikeYou),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tally: who it is about, the verdict when there is one, and the counts.
class _TallyLine extends StatelessWidget {
  const _TallyLine({required this.tally, required this.heading});

  final FitTally tally;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final verdict = tally.verdict;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: context.dsText.caption.tint(colors.onSurfaceVariant),
        ),
        DsGaps.vXxxs,
        if (verdict != null)
          Text(
            FitLabels.verdict(l10n, verdict),
            style: context.dsText.body.semibold,
          )
        else if (tally.enough)
          Text(l10n.fitOpinionsDiffer, style: context.dsText.body.semibold),
        DsGaps.vXxs,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final fit in ReviewFit.values)
              DsBadge(
                label: '${FitLabels.fit(l10n, fit)} · ${tally.countOf(fit)}',
                tone: fit == verdict
                    ? DsBadgeTone.primary
                    : DsBadgeTone.neutral,
              ),
          ],
        ),
      ],
    );
  }
}
