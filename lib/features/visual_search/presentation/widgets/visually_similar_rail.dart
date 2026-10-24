import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/visual_search/presentation/providers/visual_search_providers.dart';
import 'package:ohara/features/visual_search/presentation/widgets/visual_match_card.dart';

/// "قطع شبيهة بصريًا" — a rail for a product page.
///
/// Renders **nothing at all** when the server has no visual neighbours for
/// this product: no header, no skeleton, no "coming soon". Two cases produce
/// that, and both deserve silence rather than an apology. Either the indexer
/// has not described this listing's photographs yet, or nothing else in the
/// shop looks like it — and a rail titled "قطع شبيهة" holding a keyword match
/// would be the small lie that stops the label meaning anything.
///
/// It also holds no loading state of its own beyond a thin shimmer: the rail
/// is below the fold of a product page and its absence during the first
/// hundred milliseconds is not something anybody is waiting on.
class VisuallySimilarRail extends ConsumerWidget {
  const VisuallySimilarRail({super.key, required this.productId, this.title});

  final String productId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(visuallySimilarProvider(productId));

    return matches.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      loading: () => const _RailSkeleton(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.md,
                DsSpacing.lg,
                DsSpacing.md,
                DsSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? context.l10n.visualSimilarRail,
                      style: context.dsText.cardTitle,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(RoutePaths.visualSearch),
                    child: Text(context.l10n.visualSearchWithYourPhoto),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 340,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
                itemBuilder: (context, index) {
                  final match = items[index];
                  return SizedBox(
                    width: 170,
                    child: VisualMatchCard(
                      match: match,
                      onTap: () => context.push(
                        RoutePaths.productDetailsOf(match.product.id),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (_, _) => const DsSkeleton(width: 170, height: 320),
      ),
    );
  }
}
