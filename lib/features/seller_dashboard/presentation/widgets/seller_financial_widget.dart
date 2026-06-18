import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../commissions/presentation/providers/commission_provider.dart';
import '../providers/seller_dashboard_provider.dart';

class SellerFinancialWidget extends ConsumerWidget {
  const SellerFinancialWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;

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
              gradient: context.rewardsGradient,
              borderRadius: DsRadius.borderXxl,
              boxShadow: context.glowShadow(c.primary, blur: 28, alpha: 0.24),
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
                      'Withdrawal center',
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
                          Text(
                            '\$${_fmt(withdrawable)}',
                            style: const TextStyle(
                              fontFamily: DsTypography.fontFamilyDisplay,
                              fontFamilyFallback: DsTypography.displayFallback,
                              fontSize: 32,
                              fontWeight: DsTypography.bold,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Available to withdraw',
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
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: c.primary,
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
                      child: const Text('Withdraw'),
                    ),
                  ],
                ),
                const SizedBox(height: DsSpacing.md),
                Row(
                  children: [
                    _FinStat(label: 'Paid out', value: '\$${_fmt(paid)}'),
                    _FDivider(),
                    _FinStat(label: 'Fees', value: '\$${_fmt(fees)}'),
                    _FDivider(),
                    _FinStat(
                      label: 'Pending',
                      value:
                          '\$${_fmt(earnings.maybeWhen(data: (data) => data.pendingNet, orElse: () => 0))}',
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

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
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
        Text(
          value,
          style: const TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: DsTypography.titleSmall,
            fontWeight: DsTypography.bold,
            color: Colors.white,
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
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.22),
  );
}
