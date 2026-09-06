import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';
import 'package:reem/features/market/presentation/widgets/market_pieces.dart';

/// نزولات — launches, addressed.
///
/// Opening a drop records that she looked, which is what makes the seller's
/// precision figure a real rate rather than an impression count. It is
/// recorded once per invitation and never re-sent, so a woman who opens the
/// same drop four times is one open.
class DropsScreen extends ConsumerWidget {
  const DropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final async = ref.watch(openDropsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const ReemAppBar(title: 'نزولات'),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(openDropsProvider),
        child: async.when(
          loading: () => const Center(child: DsLoadingIndicator()),
          error: (_, _) => DsErrorState(
            message: 'ما قدرنا نجيب النزولات.',
            onRetry: () => ref.invalidate(openDropsProvider),
          ),
          data: (drops) => drops.isEmpty
              ? const DsEmptyState(
                  icon: Icons.local_fire_department_outlined,
                  title: 'ما في نزول هلق',
                  // Says what a drop is *for*, because a woman seeing this
                  // screen empty has no other way to learn it.
                  message:
                      'لما ينزل شي بيناسب اللي ناقصك أو ذوقك، بتشوفيه هون قبل ما ينفتح للكل.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(DsSpacing.lg),
                  itemCount: drops.length,
                  separatorBuilder: (_, _) => DsGaps.vMd,
                  itemBuilder: (_, index) {
                    final drop = drops[index];
                    return DropCard(
                      drop: drop,
                      onTap: () => _open(context, ref, drop),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, Drop drop) {
    // Fire and forget: a measurement must never delay her, and a failed
    // measurement must never stop her opening what she tapped.
    ref.read(marketRepositoryProvider).markDropOpened(drop.id);
    if (drop.products.isEmpty) return;
    context.push(RoutePaths.productDetailsOf(drop.products.first.productId));
  }
}

/// A drop rail for the home screen.
///
/// Renders nothing at all when there is nothing to show — not a placeholder,
/// not a skeleton that never resolves. A launch rail is an addition to a page
/// that works without it.
class DropsRail extends ConsumerWidget {
  const DropsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final drops = ref.watch(openDropsProvider).asData?.value ?? const <Drop>[];
    if (drops.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'نزل هلق',
                  style: context.dsText.cardTitle.tint(colors.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => context.push(RoutePaths.marketDrops),
                child: const Text('الكل'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            itemCount: drops.length,
            separatorBuilder: (_, _) => DsGaps.hSm,
            itemBuilder: (_, index) => SizedBox(
              width: 280,
              child: DropCard(
                drop: drops[index],
                onTap: () => context.push(RoutePaths.marketDrops),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
