import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/commissions/presentation/providers/commission_provider.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_format.dart';

/// The payout card: what she can take out today, and what the platform has
/// already paid, kept and is still holding.
///
/// It used to quote dollars and wear the buyer's rose gradient. Both are wrong
/// here — the platform settles in Syrian pounds, and this is the seller's
/// money, so it wears the atelier's champagne.
class SellerFinancialWidget extends ConsumerWidget {
  const SellerFinancialWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final palette = context.atelier;
    final l10n = context.l10n;

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
          child: DsSkeleton.box(height: 130, borderRadius: DsRadius.xxl),
        ),
      );
    }

    final store = state.data?.storeInfo;
    if (store == null) return const SizedBox.shrink();
    final earnings = ref.watch(sellerCommissionEarningsProvider);
    final withdrawable = earnings.maybeWhen(
      data: (data) => data.availableNet,
      orElse: () => store.withdrawableBalance,
    );
    final paid = earnings.maybeWhen(
      data: (data) => data.lifetimePaid,
      orElse: () => state.data!.revenue.thisYear,
    );
    final fees = earnings.maybeWhen(
      data: (data) {
        final earned = data.totals['earned'];
        return ((earned?.commission ?? 0) + (earned?.platformFees ?? 0))
            .toDouble();
      },
      orElse: () => 0.0,
    );

    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(DsSpacing.lg),
            decoration: BoxDecoration(
              gradient: palette.headerGradient,
              borderRadius: DsRadius.borderXxl,
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: DsSpacing.xs),
                    Text(
                      l10n.sellerWithdrawalCentre,
                      style: const TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: DsTypography.labelMedium,
                        fontWeight: DsTypography.semiBold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DsSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              withdrawable.sypFull,
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: DsTypography.fontFamily,
                                fontSize: 30,
                                fontWeight: DsTypography.bold,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.sellerAvailableToWithdraw,
                            style: TextStyle(
                              fontFamily: DsTypography.fontFamily,
                              fontSize: DsTypography.labelSmall,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => context.push(RoutePaths.sellerEarnings),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: palette.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.md,
                          vertical: DsSpacing.xs,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: DsTypography.fontFamily,
                          fontWeight: DsTypography.bold,
                          fontSize: DsTypography.labelMedium,
                        ),
                      ),
                      child: Text(l10n.sellerWithdraw),
                    ),
                  ],
                ),
                const SizedBox(height: DsSpacing.md),
                Row(
                  children: [
                    _FinStat(
                      label: l10n.sellerPaidOut,
                      value: paid.sypCompact,
                    ),
                    const _FDivider(),
                    _FinStat(
                      label: l10n.sellerFees,
                      value: fees.sypCompact,
                    ),
                    const _FDivider(),
                    _FinStat(
                      label: l10n.sellerPendingPayout,
                      value: earnings
                          .maybeWhen(
                            data: (data) => data.pendingNet,
                            orElse: () => 0.0,
                          )
                          .sypCompact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 380.ms);
  }

}

class _FinStat extends StatelessWidget {
  const _FinStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: DsTypography.labelSmall,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    ),
  );
}

class _FDivider extends StatelessWidget {
  const _FDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.22),
  );
}
