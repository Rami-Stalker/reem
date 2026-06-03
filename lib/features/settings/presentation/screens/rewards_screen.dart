import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Rewards', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: const EdgeInsets.all(DsSpacing.xl),
                decoration: BoxDecoration(
                  gradient: context.rewardsGradient,
                  borderRadius: DsRadius.borderXxxl,
                  boxShadow: context.luxuryShadow,
                ),
                child: Column(
                  children: [
                    Icon(Icons.stars_rounded, size: 48, color: colors.onPrimary),
                    const SizedBox(height: DsSpacing.md),
                    Text(
                      '2,450',
                      style: TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: 48,
                        fontWeight: DsTypography.bold,
                        color: colors.onPrimary,
                      ),
                    ),
                    Text(
                      'Beauty Points',
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.9),
                        fontSize: DsTypography.titleMedium,
                      ),
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    Text(
                      'Earn 1 point per \$1 · Redeem at checkout',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: DsSpacing.xxl),
              Text(
                'Redeem rewards',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: DsTypography.bold,
                    ),
              ),
              const SizedBox(height: DsSpacing.lg),
              const _RewardTile(
                points: 500,
                reward: '\$5 off',
                icon: Icons.card_giftcard_rounded,
              ),
              const _RewardTile(
                points: 1000,
                reward: 'Free shipping',
                icon: Icons.local_shipping_rounded,
              ),
              const _RewardTile(
                points: 2000,
                reward: 'Exclusive gift box',
                icon: Icons.redeem_rounded,
              ),
              const SizedBox(height: DsSpacing.xxl),
              Text(
                'How to earn',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: DsTypography.bold,
                    ),
              ),
              const SizedBox(height: DsSpacing.md),
              const _EarnRow(icon: Icons.shopping_bag_rounded, text: 'Shop products', pts: '+10/\$'),
              const _EarnRow(icon: Icons.post_add_rounded, text: 'Share a purchase post', pts: '+50'),
              const _EarnRow(icon: Icons.favorite_rounded, text: 'Like & engage', pts: '+2'),
            ]),
          ),
        ),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.points,
    required this.reward,
    required this.icon,
  });

  final int points;
  final String reward;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: GlassContainer(
        borderRadius: DsRadius.xl,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: context.primaryGradient,
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, color: colors.onPrimary, size: 22),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward, style: TextStyle(fontWeight: DsTypography.semiBold)),
                  Text(
                    '$points points',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: DsTypography.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Redeem',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: DsTypography.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({required this.icon, required this.text, required this.pts});

  final IconData icon;
  final String text;
  final String pts;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 22),
          const SizedBox(width: DsSpacing.md),
          Expanded(child: Text(text)),
          Text(
            pts,
            style: TextStyle(
              color: colors.primary,
              fontWeight: DsTypography.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}
