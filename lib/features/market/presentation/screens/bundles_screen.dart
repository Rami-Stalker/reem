import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';
import 'package:reem/features/market/presentation/widgets/market_pieces.dart';

/// إطلالات جاهزة — solutions rather than products.
///
/// The page sells a finished answer: a dress, the shoes that go with it and
/// the bag, priced together and drawn from whichever shops actually have them.
/// That last part is the reason this is not a seller's upsell rail, and it is
/// why the shop count is on every card.
class BundlesScreen extends ConsumerStatefulWidget {
  const BundlesScreen({super.key});

  @override
  ConsumerState<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends ConsumerState<BundlesScreen> {
  String? _occasion;

  /// The occasions worth filtering by, in the lexicon's own keys.
  static const _occasions = [
    'wedding',
    'evening',
    'eid',
    'graduation',
    'work',
    'daily',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final async = ref.watch(bundlesProvider(_occasion));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(title: context.l10n.marketReadyLooks),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(bundlesProvider(_occasion)),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                itemCount: _occasions.length + 1,
                separatorBuilder: (_, _) => DsGaps.hXs,
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Center(
                      child: DsChip(
                        label: context.l10n.marketAll,
                        selected: _occasion == null,
                        onTap: () => setState(() => _occasion = null),
                      ),
                    );
                  }
                  final key = _occasions[index - 1];
                  return Center(
                    child: DsChip(
                      label: marketOccasionLabel(context.l10n, key),
                      selected: _occasion == key,
                      onTap: () => setState(() => _occasion = key),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: DsLoadingIndicator()),
                error: (_, _) => DsErrorState(
                  message: context.l10n.marketLooksFailed,
                  onRetry: () => ref.invalidate(bundlesProvider(_occasion)),
                ),
                data: (bundles) {
                  if (bundles.isEmpty) {
                    return DsEmptyState(
                      icon: Icons.auto_awesome_outlined,
                      title: context.l10n.marketNoLooks,
                      // Honest about *why* it is empty. A bundle needs pieces
                      // that go together and are in stock at the same time,
                      // and saying so is better than an empty shelf.
                      message: context.l10n.marketNoLooksBody,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(DsSpacing.lg),
                    itemCount: bundles.length,
                    separatorBuilder: (_, _) => DsGaps.vMd,
                    itemBuilder: (_, index) => BundleCard(
                      bundle: bundles[index],
                      onTap: () =>
                          context.push(RoutePaths.marketBundleOf(bundles[index].id)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
