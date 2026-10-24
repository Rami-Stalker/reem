import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/policies/presentation/widgets/policy_link.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:ohara/features/seller_earnings/presentation/providers/seller_earnings_provider.dart';
import 'package:ohara/features/seller_earnings/presentation/widgets/earnings_balance_cards.dart';
import 'package:ohara/features/seller_earnings/presentation/widgets/earnings_movement_tile.dart';
import 'package:ohara/features/seller_earnings/presentation/widgets/payout_request_card.dart';

/// Q69 P1 «كشف حساب وطلب سحب الأرباح» / Q98 «الأرباح والكشوفات».
///
/// The screen answers three questions in order: what can I be paid now, what
/// is still on its way, and how did each figure get there. Everything is read
/// from the double-entry ledger, so a seller and the platform are always
/// looking at the same numbers.
class SellerEarningsScreen extends ConsumerWidget {
  const SellerEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerEarningsNotifierProvider);
    final l10n = context.l10n;
    final earnings = state.earnings;

    return OharaScrollPage(
      onRefresh: () =>
          ref.read(sellerEarningsNotifierProvider.notifier).refresh(),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        PremiumAppBar(title: l10n.sellerEarnings, showBack: true),

        if (state.isLoading)
          const SliverToBoxAdapter(child: _EarningsSkeleton())
        else if (earnings == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                message: state.issue == SellerEarningsIssue.offline
                    ? l10n.earningsOffline
                    : (state.serverError ?? l10n.earningsOffline),
                onRetry: () =>
                    ref.read(sellerEarningsNotifierProvider.notifier).refresh(),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: EarningsBalanceCards(
              earnings: earnings,
              isRefreshing: state.isRefreshing,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xl)),

          // The half of Q69 P1 this screen was missing: asking to be paid.
          const SliverToBoxAdapter(child: PayoutRequestCard()),
          const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xl)),

          // Anything else outstanding — a payout the platform prepared itself,
          // for instance. The request the card above already renders is left
          // out rather than shown twice.
          if (_otherPayouts(state).isNotEmpty) ...[
            _sectionHeader(context, l10n.earningsPendingPayouts),
            SliverList.separated(
              itemCount: _otherPayouts(state).length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xs),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                child: _PendingPayoutTile(payout: _otherPayouts(state)[index]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xl)),
          ],

          _sectionHeader(context, l10n.earningsLifetime),
          SliverToBoxAdapter(child: _LifetimeCard(earnings: earnings)),
          const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xl)),

          if (earnings.movements.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.earningsEmptyTitle,
                  message: l10n.earningsEmptyBody,
                ),
              ),
            )
          else ...[
            _sectionHeader(context, l10n.earningsStatement),
            SliverList.separated(
              itemCount: earnings.movements.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xs),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                child: EarningsMovementTile(
                  movement: earnings.movements[index],
                ),
              ),
            ),
          ],
        ],

        // Why a figure is held and when it is released is a commissions
        // question, and this is the screen where it gets asked. The policy is
        // the platform's written answer, so the screen links to it rather than
        // restating half of it in a tooltip that can drift from the document.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xl,
              DsSpacing.lg,
              0,
            ),
            child: PolicyNotice(
              message: l10n.sellerEarningsPolicyNotice,
              links: [
                PolicyLink(
                  label: l10n.policiesLinkCommissions,
                  slug: PolicySlugs.commissions,
                ),
              ],
            ),
          ),
        ),

        DsGaps.sliverBottomSafe,
      ],
    );
  }

  /// Outstanding payouts the withdrawal card is not already showing.
  List<PendingPayout> _otherPayouts(SellerEarningsState state) {
    final shown = state.availability?.openRequest?.id;
    final all = state.earnings?.pendingPayouts ?? const <PendingPayout>[];
    return [
      for (final payout in all)
        if (payout.id != shown) payout,
    ];
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.xxxs,
          DsSpacing.lg,
          DsSpacing.md,
        ),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: DsTypography.bold),
        ),
      ),
    );
  }
}

/// Gross, commission and what actually reached her — the three numbers that
/// make a commission rate feel fair or not.
class _LifetimeCard extends StatelessWidget {
  const _LifetimeCard({required this.earnings});

  final SellerEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: DsRadius.borderCard,
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            _row(context, l10n.earningsLifetimeGross, earnings.lifetimeGross),
            const SizedBox(height: DsSpacing.sm),
            _row(
              context,
              l10n.earningsLifetimeCommission,
              earnings.lifetimeCommission,
              isDeduction: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
              child: Divider(height: 1, color: colors.divider),
            ),
            _row(
              context,
              l10n.earningsLifetimePaid,
              earnings.lifetimePaid,
              emphasise: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    Money amount, {
    bool isDeduction = false,
    bool emphasise = false,
  }) {
    final colors = context.dsColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.dsText.body
                .tint(emphasise ? colors.onSurface : colors.onSurfaceVariant)
                .copyWith(
                  fontWeight: emphasise
                      ? DsTypography.bold
                      : DsTypography.regular,
                ),
          ),
        ),
        Text(
          // The minus makes it plain that commission came *out* of the gross.
          '${isDeduction ? '−' : ''}${amount.format()}',
          style:
              (emphasise
                      ? context.dsText.price
                      : context.dsText.body.bold.tint(colors.onSurface))
                  .tabular,
        ),
      ],
    );
  }
}

class _PendingPayoutTile extends StatelessWidget {
  const _PendingPayoutTile({required this.payout});

  final PendingPayout payout;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: DsBadge(
              label: payout.isApproved
                  ? l10n.earningsPayoutApproved
                  : l10n.earningsPayoutPending,
              tone: payout.isApproved
                  ? DsBadgeTone.success
                  : DsBadgeTone.neutral,
            ),
          ),
          Text(
            payout.net.format(),
            style: context.dsText.body.bold.tint(colors.onSurface),
          ),
        ],
      ),
    );
  }
}

class _EarningsSkeleton extends StatelessWidget {
  const _EarningsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.box(height: 150, borderRadius: DsRadius.card),
            SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DsSkeleton.box(
                    height: 96,
                    borderRadius: DsRadius.card,
                  ),
                ),
                SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: DsSkeleton.box(
                    height: 96,
                    borderRadius: DsRadius.card,
                  ),
                ),
              ],
            ),
            SizedBox(height: DsSpacing.xl),
            DsSkeleton.line(width: 120),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 64, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.xs),
            DsSkeleton.box(height: 64, borderRadius: DsRadius.lg),
          ],
        ),
      ),
    );
  }
}
