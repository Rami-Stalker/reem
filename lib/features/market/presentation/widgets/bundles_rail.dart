import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';
import 'package:reem/features/market/presentation/widgets/market_pieces.dart';

/// A rail of assembled looks, for the home page.
///
/// Draws nothing until there is a bundle to draw, like every other optional
/// rail here. The subtitle carries the claim — pieces from different shops,
/// chosen because they go together — because without it the rail reads as
/// another shelf of products and the whole point is that it is not one.
class BundlesRail extends ConsumerWidget {
  const BundlesRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final bundles =
        ref.watch(bundlesProvider(null)).asData?.value ?? const <Bundle>[];
    if (bundles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.marketReadyLooks,
                      style: context.dsText.cardTitle.tint(colors.onSurface),
                    ),
                    Text(
                      context.l10n.marketReadyLooksBody,
                      style: context.dsText.caption.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(RoutePaths.marketBundles),
                child: Text(context.l10n.marketAll),
              ),
            ],
          ),
        ),
        DsGaps.vXs,
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            itemCount: bundles.length,
            separatorBuilder: (_, _) => DsGaps.hSm,
            itemBuilder: (_, index) => SizedBox(
              width: 280,
              child: BundleCard(
                bundle: bundles[index],
                onTap: () =>
                    context.push(RoutePaths.marketBundleOf(bundles[index].id)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
