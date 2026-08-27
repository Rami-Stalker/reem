import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/features/rewards/domain/entities/rewards_hub.dart';
import 'package:reem/features/rewards/presentation/providers/rewards_hub_provider.dart';

import '../../../../core/design_system/design_system.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  final _referralController = TextEditingController();

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RewardsHubState>(rewardsHubNotifierProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.error != null && next.error != previous?.error) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(next.error!),
            ),
          );
      }
      if (next.success != null && next.success != previous?.success) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(next.success!),
            ),
          );
      }
    });

    final state = ref.watch(rewardsHubNotifierProvider);
    final hub = state.hub;

    return ReemScrollPage(
      onRefresh: () =>
          ref.read(rewardsHubNotifierProvider.notifier).load(refresh: true),
      slivers: [
        const PremiumAppBar(title: 'Rewards', showBack: true),
        if (state.isLoading && hub == null)
          const _LoadingSliver()
        else if (hub == null)
          _ErrorSliver(
            message: state.error ?? 'Rewards are not available right now.',
            onRetry: () => ref.read(rewardsHubNotifierProvider.notifier).load(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.lg,
              DsSpacing.lg,
              DsSpacing.xxxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _RewardsHero(hub: hub, refreshing: state.isRefreshing),
                const SizedBox(height: DsSpacing.lg),
                _ReferralPanel(
                  referral: hub.referral,
                  controller: _referralController,
                  isApplying: state.isApplyingCode,
                  onApply: () async {
                    await ref
                        .read(rewardsHubNotifierProvider.notifier)
                        .applyCode(_referralController.text);
                    if (mounted &&
                        ref.read(rewardsHubNotifierProvider).error == null) {
                      _referralController.clear();
                    }
                  },
                ),
                const SizedBox(height: DsSpacing.lg),
                _CashbackPanel(
                  cashback: hub.cashback,
                  isRedeeming: state.isRedeemingCashback,
                  onRedeem: () => ref
                      .read(rewardsHubNotifierProvider.notifier)
                      .redeemCashback(),
                ),
                const SizedBox(height: DsSpacing.xl),
                _SectionTitle(
                  title: 'Redeem rewards',
                  subtitle: '${hub.rewards.length} available offers',
                ),
                const SizedBox(height: DsSpacing.md),
                if (hub.rewards.isEmpty)
                  const _EmptyState(
                    icon: Icons.card_giftcard_rounded,
                    title: 'No rewards yet',
                    body: 'New membership offers will appear here.',
                  )
                else
                  for (final reward in hub.rewards)
                    _RewardTile(
                      reward: reward,
                      availablePoints: hub.points,
                      isBusy: state.busyRewardId == reward.id,
                      onRedeem: () => ref
                          .read(rewardsHubNotifierProvider.notifier)
                          .redeemReward(reward),
                    ),
                const SizedBox(height: DsSpacing.xl),
                _SectionTitle(
                  title: 'Tier benefits',
                  subtitle: hub.membership.nextTierName == null
                      ? 'You are at the highest tier'
                      : 'Next tier: ${hub.membership.nextTierName}',
                ),
                const SizedBox(height: DsSpacing.md),
                _BenefitsPanel(membership: hub.membership),
              ]),
            ),
          ),
      ],
    );
  }
}

class _RewardsHero extends StatelessWidget {
  const _RewardsHero({required this.hub, required this.refreshing});

  final RewardsHub hub;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final membership = hub.membership;
    return Semantics(
      label: 'Rewards balance ${hub.points} points, ${membership.tierName} tier',
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.xl),
        decoration: BoxDecoration(
          gradient: context.rewardsGradient,
          borderRadius: DsRadius.borderXxxl,
          boxShadow: context.luxuryShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: colors.onPrimary, size: 28),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Text(
                    membership.vip
                        ? '${membership.tierName} VIP'
                        : '${membership.tierName} member',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: DsTypography.bold,
                      fontSize: DsTypography.titleMedium,
                    ),
                  ),
                ),
                if (refreshing)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DsSpacing.lg),
            Text(
              '${hub.points}',
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: 48,
                height: 1,
                fontWeight: DsTypography.bold,
                color: colors.onPrimary,
              ),
            ),
            Text(
              'available points',
              style: TextStyle(
                color: colors.onPrimary.withValues(alpha: 0.88),
                fontSize: DsTypography.titleSmall,
              ),
            ),
            const SizedBox(height: DsSpacing.lg),
            _ProgressBar(
              value: membership.progress,
              foreground: colors.onPrimary,
              background: colors.onPrimary.withValues(alpha: 0.24),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              membership.nextTierName == null
                  ? 'Top tier unlocked'
                  : '${(membership.progress * 100).round()}% toward ${membership.nextTierName}',
              style: TextStyle(
                color: colors.onPrimary.withValues(alpha: 0.86),
                fontWeight: DsTypography.medium,
              ),
            ),
            const SizedBox(height: DsSpacing.lg),
            Row(
              children: [
                _HeroMetric(
                  label: 'Lifetime',
                  value: '${hub.lifetimePoints}',
                ),
                _HeroMetric(
                  label: 'Cashback',
                  value: _money(hub.cashback.available),
                ),
                _HeroMetric(
                  label: 'Bonus',
                  value: '${membership.pointsMultiplier}x',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.titleMedium,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );
  }
}

class _ReferralPanel extends StatelessWidget {
  const _ReferralPanel({
    required this.referral,
    required this.controller,
    required this.isApplying,
    required this.onApply,
  });

  final ReferralSummary referral;
  final TextEditingController controller;
  final bool isApplying;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.group_add_rounded,
            title: 'Invite friends',
            subtitle: 'Track customer and seller referrals in one place.',
          ),
          const SizedBox(height: DsSpacing.md),
          _CodeRow(
            label: 'Customer code',
            code: referral.customerCode,
            onCopy: () => _copy(context, referral.customerCode),
          ),
          const SizedBox(height: DsSpacing.sm),
          _CodeRow(
            label: 'Seller code',
            code: referral.sellerCode,
            onCopy: () => _copy(context, referral.sellerCode),
          ),
          const SizedBox(height: DsSpacing.lg),
          Row(
            children: [
              _CompactStat(value: '${referral.total}', label: 'Invited'),
              _CompactStat(value: '${referral.rewarded}', label: 'Rewarded'),
              _CompactStat(value: '${referral.pointsEarned}', label: 'Points'),
              _CompactStat(value: _money(referral.cashbackEarned), label: 'Cashback'),
            ],
          ),
          if (referral.suspicious > 0) ...[
            const SizedBox(height: DsSpacing.md),
            _InlineNotice(
              icon: Icons.shield_outlined,
              text: '${referral.suspicious} referral checks are under review.',
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Have a referral code?',
              hintText: 'Enter code',
              prefixIcon: Icon(Icons.confirmation_number_outlined,
                  color: colors.primary),
            ),
            onSubmitted: (_) => onApply(),
          ),
          const SizedBox(height: DsSpacing.md),
          DsButton(
            label: 'Apply code',
            icon: Icons.check_circle_outline_rounded,
            size: DsButtonSize.md,
            isLoading: isApplying,
            onPressed: isApplying ? null : onApply,
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$code copied'),
        ),
      );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.label,
    required this.code,
    required this.onCopy,
  });

  final String label;
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              border: Border.all(color: colors.border),
              borderRadius: DsRadius.borderLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: DsTypography.labelSmall,
                        ),
                      ),
                      Text(
                        code.isEmpty ? 'Generating' : code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: DsTypography.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: DsSpacing.sm),
        Tooltip(
          message: 'Copy $label',
          child: IconButton.filledTonal(
            onPressed: code.isEmpty ? null : onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
        ),
      ],
    );
  }
}

class _CashbackPanel extends StatelessWidget {
  const _CashbackPanel({
    required this.cashback,
    required this.isRedeeming,
    required this.onRedeem,
  });

  final CashbackSummary cashback;
  final bool isRedeeming;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.savings_outlined,
            title: 'Cashback',
            subtitle: 'Convert earned cashback into checkout coupons.',
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              _CashbackMetric(label: 'Available', value: _money(cashback.available)),
              _CashbackMetric(label: 'Pending', value: _money(cashback.pending)),
              _CashbackMetric(
                  label: 'Lifetime', value: _money(cashback.lifetimeEarned)),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          DsButton(
            label: 'Convert to coupon',
            icon: Icons.local_offer_outlined,
            size: DsButtonSize.md,
            isLoading: isRedeeming,
            onPressed:
                cashback.available <= 0 || isRedeeming ? null : onRedeem,
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.availablePoints,
    required this.isBusy,
    required this.onRedeem,
  });

  final LoyaltyRewardItem reward;
  final int availablePoints;
  final bool isBusy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final canRedeem = reward.canRedeem(availablePoints);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: GlassContainer(
        borderRadius: DsRadius.xl,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: reward.exclusive
                    ? DsGradients.champagne
                    : context.primaryGradient,
                borderRadius: DsRadius.borderLg,
              ),
              child: Icon(_rewardIcon(reward.type), color: colors.onPrimary),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: DsTypography.semiBold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rewardSubtitle(reward),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: DsTypography.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            DsButton(
              label: reward.exclusive ? 'Claim' : 'Redeem',
              size: DsButtonSize.sm,
              variant: canRedeem
                  ? DsButtonVariant.accent
                  : DsButtonVariant.secondary,
              isExpanded: false,
              isLoading: isBusy,
              onPressed: canRedeem && !isBusy ? onRedeem : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsPanel extends StatelessWidget {
  const _BenefitsPanel({required this.membership});

  final MembershipSummary membership;

  @override
  Widget build(BuildContext context) {
    final benefits = membership.benefits.isEmpty
        ? const ['Points on every order', 'Referral rewards', 'Member offers']
        : membership.benefits;
    return SurfaceCard(
      child: Column(
        children: [
          _BenefitRow(
            icon: Icons.stars_rounded,
            title: '${membership.pointsMultiplier}x point multiplier',
            subtitle: 'Tier bonus is applied after eligible purchases.',
          ),
          const SizedBox(height: DsSpacing.md),
          _BenefitRow(
            icon: Icons.payments_outlined,
            title: '${membership.cashbackRate}% cashback rate',
            subtitle: 'Cashback can be converted into coupons.',
          ),
          const SizedBox(height: DsSpacing.md),
          for (final benefit in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.sm),
              child: _InlineNotice(
                icon: Icons.check_circle_outline_rounded,
                text: benefit,
              ),
            ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        Icon(icon, color: colors.primary),
        const SizedBox(width: DsSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: DsTypography.bold)),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: DsTypography.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: DsTypography.bold),
              ),
              Text(
                subtitle,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        Icon(icon, color: colors.primary),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: DsTypography.bold)),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: DsTypography.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: DsTypography.bold),
          ),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: DsTypography.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashbackMetric extends StatelessWidget {
  const _CashbackMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: DsTypography.titleMedium,
              fontWeight: DsTypography.bold,
            ),
          ),
          Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 18),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: DsTypography.labelMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.foreground,
    required this.background,
  });

  final double value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DsRadius.borderFull,
      child: Stack(
        children: [
          Container(height: 8, color: background),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1).toDouble(),
            child: Container(height: 8, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SurfaceCard(
      child: Column(
        children: [
          Icon(icon, color: colors.primary, size: 36),
          const SizedBox(height: DsSpacing.sm),
          Text(title, style: TextStyle(fontWeight: DsTypography.bold)),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          const [
            DsShimmer(
              child: DsSkeleton.box(height: 220, borderRadius: DsRadius.xxl),
            ),
            SizedBox(height: DsSpacing.lg),
            DsShimmer(
              child: DsSkeleton.box(height: 190, borderRadius: DsRadius.xxl),
            ),
            SizedBox(height: DsSpacing.lg),
            DsShimmer(
              child: DsSkeleton.box(height: 120, borderRadius: DsRadius.xxl),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorSliver extends StatelessWidget {
  const _ErrorSliver({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: colors.primary),
            const SizedBox(height: DsSpacing.md),
            Text(
              'Rewards could not load',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: DsTypography.bold),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: DsSpacing.lg),
            DsButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              isExpanded: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _rewardIcon(String type) {
  return switch (type) {
    'cashback' => Icons.savings_outlined,
    'free_shipping' => Icons.local_shipping_outlined,
    'exclusive_offer' => Icons.workspace_premium_outlined,
    'gift' => Icons.redeem_outlined,
    'points' => Icons.stars_outlined,
    _ => Icons.local_offer_outlined,
  };
}

String _rewardSubtitle(LoyaltyRewardItem reward) {
  final parts = <String>[
    if (reward.description != null && reward.description!.isNotEmpty)
      reward.description!,
    if (reward.pointsCost != null) '${reward.pointsCost} points',
    if (reward.cashbackAmount != null) _money(reward.cashbackAmount!),
    if (reward.exclusive) 'Exclusive',
  ];
  return parts.isEmpty ? 'Member reward' : parts.join(' - ');
}

String _money(double value) {
  if (value == value.roundToDouble()) {
    return '\$${value.toInt()}';
  }
  return '\$${value.toStringAsFixed(2)}';
}
