import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/shared/value_objects/money.dart';
import '../../domain/entities/seller_earnings.dart';
import '../providers/seller_earnings_provider.dart';
import '../widgets/earnings_balance_cards.dart';
import '../widgets/earnings_movement_tile.dart';

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

    return ReemScrollPage(
      onRefresh: () =>
          ref.read(sellerEarningsNotifierProvider.notifier).refresh(),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.sellerEarnings),
        ),

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

          if (earnings.pendingPayouts.isNotEmpty) ...[
            _sectionHeader(context, l10n.earningsPendingPayouts),
            SliverList.separated(
              itemCount: earnings.pendingPayouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xs),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                child: _PendingPayoutTile(
                  payout: earnings.pendingPayouts[index],
                ),
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

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          0,
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
            style: TextStyle(
              fontSize: DsTypography.bodyMedium,
              fontWeight: emphasise
                  ? DsTypography.bold
                  : DsTypography.regular,
              color: emphasise ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          // The minus makes it plain that commission came *out* of the gross.
          '${isDeduction ? '−' : ''}${amount.format()}',
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: emphasise
                ? DsTypography.titleSmall
                : DsTypography.bodyMedium,
            fontWeight: DsTypography.bold,
            color: emphasise ? colors.price : colors.onSurface,
          ),
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
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.bodyMedium,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
            ),
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
                  child: DsSkeleton.box(height: 96, borderRadius: DsRadius.card),
                ),
                SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: DsSkeleton.box(height: 96, borderRadius: DsRadius.card),
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
