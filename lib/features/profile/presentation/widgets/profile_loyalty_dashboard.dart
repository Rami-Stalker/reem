import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/loyalty.dart';
import '../providers/profile_overview_provider.dart';

/// The loyalty dashboard — a jewel-toned membership card with points, tier
/// progress and at-a-glance lifetime / coupons / redeemed stats.
class ProfileLoyaltyDashboard extends ConsumerWidget {
  const ProfileLoyaltyDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.isInitialLoading),
    );
    final loyalty = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.overview?.loyalty),
    );

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 196, borderRadius: DsRadius.xxl)),
      );
    }
    if (loyalty == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.rewards),
        child: Container(
          padding: const EdgeInsets.all(DsSpacing.lg),
          decoration: BoxDecoration(
            gradient: context.rewardsGradient,
            borderRadius: DsRadius.borderXxl,
            boxShadow:
                context.glowShadow(context.dsColors.primary, blur: 28, alpha: 0.26),
          ),
          child: _Body(loyalty: loyalty),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.loyalty});

  final LoyaltySummary loyalty;
  static const _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    final faint = _white.withValues(alpha: 0.86);
    final track = _white.withValues(alpha: 0.25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: _white, size: 22),
            const SizedBox(width: DsSpacing.xs),
            Text('${loyalty.tier.label} member',
                style: DsTypography.overline(faint)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: _white, size: 20),
          ],
        ),
        const SizedBox(height: DsSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${loyalty.points}',
                style: const TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: 34,
                  fontWeight: DsTypography.bold,
                  color: _white,
                  height: 1,
                )),
            const SizedBox(width: DsSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('points',
                  style: TextStyle(color: faint, fontWeight: DsTypography.medium)),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.sm),
        if (loyalty.nextTier != null) ...[
          ClipRRect(
            borderRadius: DsRadius.borderFull,
            child: Stack(
              children: [
                Container(height: 7, color: track),
                FractionallySizedBox(
                  widthFactor: loyalty.tierProgress,
                  child: Container(height: 7, color: _white),
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(loyalty.rewardHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: faint,
                  fontSize: DsTypography.labelMedium,
                  fontWeight: DsTypography.medium)),
        ],
        const SizedBox(height: DsSpacing.md),
        Row(
          children: [
            _Stat(value: '${loyalty.availableCoupons}', label: 'Coupons'),
            _StatDivider(),
            _Stat(value: '${loyalty.lifetimePoints ?? loyalty.points}', label: 'Lifetime'),
            _StatDivider(),
            _Stat(value: '${loyalty.redeemedCount ?? 0}', label: 'Redeemed'),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.titleSmall,
                fontWeight: DsTypography.bold,
                color: Colors.white,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: DsTypography.labelSmall,
                color: Colors.white.withValues(alpha: 0.8),
              )),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.22));
}
