import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/rewards/domain/entities/rewards_hub.dart';
import 'package:reem/features/rewards/presentation/providers/rewards_hub_provider.dart';

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
    final l10n = context.l10n;
    ref.listen<RewardsHubState>(rewardsHubNotifierProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final error = next.errorMessage?.resolve(context.l10n) ?? next.error;
      final previousError =
          previous?.errorMessage?.resolve(context.l10n) ?? previous?.error;
      if (error != null && error != previousError) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(error),
            ),
          );
      }
      final success =
          next.successMessage?.resolve(context.l10n) ?? next.success;
      final previousSuccess =
          previous?.successMessage?.resolve(context.l10n) ?? previous?.success;
      if (success != null && success != previousSuccess) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(success),
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
        PremiumAppBar(title: context.l10n.rewardsTitle, showBack: true),
        if (state.isLoading && hub == null)
          const _LoadingSliver()
        else if (hub == null)
          _ErrorSliver(
            message: state.errorMessage?.resolve(l10n) ??
                state.error ??
                l10n.rewardsUnavailable,
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
                        ref.read(rewardsHubNotifierProvider).errorMessage == null &&
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
                  title: l10n.rewardsRedeemSection,
                  subtitle: l10n.rewardsOffersCount(hub.rewards.length),
                ),
                const SizedBox(height: DsSpacing.md),
                if (hub.rewards.isEmpty)
                  _EmptyState(
                    icon: Icons.card_giftcard_rounded,
                    title: l10n.rewardsEmptyTitle,
                    body: l10n.rewardsEmptyBody,
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
                  title: l10n.rewardsTierSection,
                  subtitle: hub.membership.nextTierName == null
                      ? l10n.rewardsTopTier
                      : l10n.rewardsNextTier(hub.membership.nextTierName!),
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
      label: context.l10n
          .rewardsBalanceSemantics(hub.points, membership.tierName),
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
                        ? context.l10n.rewardsTierVip(membership.tierName)
                        : context.l10n.rewardsTierMember(membership.tierName),
                    style: context.dsText.cardTitle.bold.tint(colors.onPrimary),
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
              style: context.dsText.hero
                    .uiFamily
                    .tint(colors.onPrimary)
                    // ds-ignore: no-literal-font-sizes -- the single figure
                    // the whole rewards card exists to show, above the scale.
                    .copyWith(fontSize: 48, height: 1),
            ),
            Text(
              context.l10n.rewardsAvailablePoints,
              style: context.dsText.tileTitle.tint(colors.onPrimary.withValues(alpha: 0.88)),
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
                  ? context.l10n.rewardsTopTierUnlocked
                  : context.l10n.rewardsProgressToward(
                      (membership.progress * 100).round(),
                      membership.nextTierName!,
                    ),
              style: context.dsText.body.medium.tint(colors.onPrimary.withValues(alpha: 0.86)),
            ),
            const SizedBox(height: DsSpacing.lg),
            Row(
              children: [
                _HeroMetric(
                  label: context.l10n.rewardsLifetime,
                  value: '${hub.lifetimePoints}',
                ),
                _HeroMetric(
                  label: context.l10n.rewardsCashback,
                  value: _money(hub.cashback.available),
                ),
                _HeroMetric(
                  label: context.l10n.rewardsBonus,
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
            style: context.dsText.cardTitle.bold.tint(DsColors.onMedia),
          ),
          DsGaps.vXxxs,
          Text(
            label,
            style: context.dsText.body.tint(DsColors.onMedia.withValues(alpha: 0.72)),
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
    final l10n = context.l10n;
    final colors = context.dsColors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.group_add_rounded,
            title: l10n.rewardsInviteTitle,
            subtitle: l10n.rewardsInviteBody,
          ),
          const SizedBox(height: DsSpacing.md),
          _CodeRow(
            label: l10n.rewardsCustomerCode,
            code: referral.customerCode,
            onCopy: () => _copy(context, referral.customerCode),
          ),
          const SizedBox(height: DsSpacing.sm),
          _CodeRow(
            label: l10n.rewardsSellerCode,
            code: referral.sellerCode,
            onCopy: () => _copy(context, referral.sellerCode),
          ),
          const SizedBox(height: DsSpacing.lg),
          Row(
            children: [
              _CompactStat(value: '${referral.total}', label: l10n.rewardsInvited),
              _CompactStat(value: '${referral.rewarded}', label: l10n.rewardsRewarded),
              _CompactStat(value: '${referral.pointsEarned}', label: l10n.rewardsPoints),
              _CompactStat(value: _money(referral.cashbackEarned), label: l10n.rewardsCashback),
            ],
          ),
          if (referral.suspicious > 0) ...[
            const SizedBox(height: DsSpacing.md),
            _InlineNotice(
              icon: Icons.shield_outlined,
              text: l10n.rewardsSuspiciousChecks(referral.suspicious),
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.rewardsHaveCode,
              hintText: l10n.rewardsEnterCode,
              prefixIcon: Icon(Icons.confirmation_number_outlined,
                  color: colors.primary),
            ),
            onSubmitted: (_) => onApply(),
          ),
          const SizedBox(height: DsSpacing.md),
          DsButton(
            label: l10n.rewardsApplyCode,
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
          content: Text(context.l10n.rewardsCodeCopied(code)),
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
                        style: context.dsText.caption.tint(colors.onSurfaceVariant),
                      ),
                      Text(
                        code.isEmpty ? context.l10n.rewardsGenerating : code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.bold.tint(colors.onSurface),
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
          message: context.l10n.rewardsCopyLabel(label),
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
    final l10n = context.l10n;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.savings_outlined,
            title: l10n.rewardsCashback,
            subtitle: l10n.rewardsCashbackBody,
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              _CashbackMetric(label: l10n.rewardsAvailable, value: _money(cashback.available)),
              _CashbackMetric(label: l10n.rewardsPending, value: _money(cashback.pending)),
              _CashbackMetric(
                  label: l10n.rewardsLifetime,
                  value: _money(cashback.lifetimeEarned)),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          DsButton(
            label: l10n.rewardsConvertToCoupon,
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
    final l10n = context.l10n;
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
                    style: context.dsText.body.semibold,
                  ),
                  DsGaps.vXxxs,
                  Text(
                    _rewardSubtitle(context, reward),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.labelMedium.tint(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            DsButton(
              label: reward.exclusive ? l10n.rewardsClaim : l10n.rewardsRedeem,
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
    final l10n = context.l10n;
    final benefits = membership.benefits.isEmpty
        ? [
            l10n.rewardsBenefitPoints,
            l10n.rewardsBenefitReferrals,
            l10n.rewardsBenefitOffers,
          ]
        : membership.benefits;
    return SurfaceCard(
      child: Column(
        children: [
          _BenefitRow(
            icon: Icons.stars_rounded,
            title: l10n.rewardsMultiplier('${membership.pointsMultiplier}'),
            subtitle: l10n.rewardsTierBonusNote,
          ),
          const SizedBox(height: DsSpacing.md),
          _BenefitRow(
            icon: Icons.payments_outlined,
            title: l10n.rewardsCashbackRate('${membership.cashbackRate}'),
            subtitle: l10n.rewardsCashbackNote,
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
              Text(title, style: context.dsText.body.bold),
              Text(
                subtitle,
                style: context.dsText.labelMedium.tint(colors.onSurfaceVariant),
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
                style: context.dsText.body.tint(colors.onSurfaceVariant),
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
              Text(title, style: context.dsText.body.bold),
              Text(
                subtitle,
                style: context.dsText.labelMedium.tint(colors.onSurfaceVariant),
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
            style: context.dsText.body.bold,
          ),
          Text(
            label,
            style: context.dsText.caption.tint(colors.onSurfaceVariant),
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
            style: context.dsText.cardTitle.bold,
          ),
          Text(label, style: context.dsText.body.tint(colors.onSurfaceVariant)),
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
            style: context.dsText.labelMedium.tint(colors.onSurfaceVariant),
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
          Text(title, style: context.dsText.body.bold),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
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
    final l10n = context.l10n;
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
              context.l10n.rewardsLoadFailed,
              style: context.dsText.sectionTitle.bold,
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.dsText.body.tint(colors.onSurfaceVariant),
            ),
            const SizedBox(height: DsSpacing.lg),
            DsButton(
              label: l10n.retry,
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

String _rewardSubtitle(BuildContext context, LoyaltyRewardItem reward) {
  final parts = <String>[
    if (reward.description != null && reward.description!.isNotEmpty)
      reward.description!,
    if (reward.pointsCost != null)
      context.l10n.rewardsPointsCost(reward.pointsCost!),
    if (reward.cashbackAmount != null) _money(reward.cashbackAmount!),
    if (reward.exclusive) context.l10n.rewardsExclusive,
  ];
  return parts.isEmpty ? context.l10n.rewardsMemberReward : parts.join(' - ');
}

/// Cashback, in the currency the platform actually charges.
///
/// This printed dollars — `$0`, `$50` — on a screen whose every other figure
/// is in ل.س. `SypFormat` exists for exactly these bare-double dashboards and
/// gives the right symbol, the right grouping and no fraction digits, since
/// SYP is charged in whole units.
String _money(double value) => value.sypFull;
