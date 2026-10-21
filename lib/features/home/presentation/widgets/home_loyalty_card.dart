import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/loyalty.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';

/// The loyalty & rewards widget — a jewel-toned membership card showing points,
/// tier progress, available coupons and a personalized reward nudge.
class HomeLoyaltyCard extends ConsumerWidget {
  const HomeLoyaltyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final loyalty = ref.watch(
      homeContentNotifierProvider.select((s) => s.content?.loyalty),
    );

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
          child: DsSkeleton.box(height: 168, borderRadius: DsRadius.xxl),
        ),
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
            boxShadow: context.glowShadow(
              context.dsColors.primary,
              blur: 28,
              alpha: 0.28,
            ),
          ),
          child: _LoyaltyBody(loyalty: loyalty),
        ),
      ),
    );
  }
}

class _LoyaltyBody extends StatelessWidget {
  const _LoyaltyBody({required this.loyalty});

  final LoyaltySummary loyalty;

  static const _white = DsColors.onMedia;

  @override
  Widget build(BuildContext context) {
    final faint = _white.withValues(alpha: 0.86);
    final track = _white.withValues(alpha: 0.25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DsSpacing.xs),
              decoration: BoxDecoration(
                color: _white.withValues(alpha: 0.18),
                borderRadius: DsRadius.borderMd,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _white,
                size: 22,
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.rewardsTierMember(switch (loyalty.tier) {
                    LoyaltyTier.rose => context.l10n.loyaltyTierRose,
                    LoyaltyTier.gold => context.l10n.loyaltyTierGold,
                    LoyaltyTier.platinum => context.l10n.loyaltyTierPlatinum,
                    LoyaltyTier.diamond => context.l10n.loyaltyTierDiamond,
                  }),
                  style: DsTypography.overline(faint),
                ),
                Text(
                  context.l10n.homeLoyaltyTitle,
                  style: context.dsText.cardTitle.displayFamily.bold.tint(
                    _white,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${loyalty.points}',
                  style: context.dsText.screenTitle.bold
                      .tint(_white)
                      .copyWith(height: 1),
                ),
                Text('points', style: DsTypography.overline(faint)),
              ],
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
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
        ],
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 14, color: _white),
            const SizedBox(width: DsSpacing.xxs),
            Expanded(
              child: Text(
                loyalty.rewardHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.labelMedium.tint(faint),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        Row(
          children: [
            Expanded(
              child: _LoyaltyAction(
                icon: Icons.confirmation_number_outlined,
                label: context.l10n.homeLoyaltyCoupons(
                  loyalty.availableCoupons,
                ),
                onTap: () => context.push(RoutePaths.coupons),
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: _LoyaltyAction(
                icon: Icons.redeem_rounded,
                label: context.l10n.redeem,
                onTap: () => context.push(RoutePaths.rewards),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoyaltyAction extends StatelessWidget {
  const _LoyaltyAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
        decoration: BoxDecoration(
          color: DsColors.onMedia.withValues(alpha: 0.16),
          borderRadius: DsRadius.borderFull,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: DsColors.onMedia),
            const SizedBox(width: DsSpacing.xxs),
            Text(
              label,
              style: context.dsText.labelMedium.semibold.tint(DsColors.onMedia),
            ),
          ],
        ),
      ),
    );
  }
}
