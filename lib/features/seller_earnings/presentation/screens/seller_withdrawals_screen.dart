import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:ohara/features/seller_earnings/presentation/providers/seller_earnings_provider.dart';
import 'package:ohara/features/seller_earnings/presentation/widgets/payout_request_card.dart';

/// «مركز السحب» — asking to be paid, where it goes, and what became of each
/// request. The statement itself stays on «أرباحي»; this page is only the
/// money leaving.
class SellerWithdrawalsScreen extends ConsumerWidget {
  const SellerWithdrawalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(sellerEarningsNotifierProvider);
    final history = ref.watch(payoutHistoryProvider);

    Future<void> refresh() async {
      ref.invalidate(payoutHistoryProvider);
      await ref.read(sellerEarningsNotifierProvider.notifier).refresh();
    }

    return OharaScrollPage(
      onRefresh: refresh,
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.account_balance_wallet_rounded,
          title: l10n.sellerWithdrawalCentre,
          subtitle: l10n.withdrawalSubtitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        if (state.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(DsSpacing.xxl),
              child: Center(child: DsLoadingIndicator()),
            ),
          )
        else if (state.availability == null)
          SliverToBoxAdapter(
            child: DsErrorState(
              message: state.serverError ?? l10n.earningsOffline,
              onRetry: refresh,
            ),
          )
        else
          // Asking, and where the money will go.
          const SliverToBoxAdapter(child: PayoutRequestCard()),
        DsGaps.sliverLg,
        const SliverToBoxAdapter(child: _HowItWorks()),
        DsGaps.sliverLg,
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
          sliver: SliverToBoxAdapter(
            child: AtelierHeading(title: l10n.withdrawalHistory),
          ),
        ),
        DsGaps.sliverSm,
        ...history.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Center(child: DsLoadingIndicator.inline()),
            ),
          ],
          error: (error, _) => [
            SliverToBoxAdapter(
              child: DsErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(payoutHistoryProvider),
              ),
            ),
          ],
          data: (payouts) => payouts.isEmpty
              ? [
                  SliverToBoxAdapter(
                    child: DsEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.withdrawalHistoryEmpty,
                      message: l10n.withdrawalHistoryEmptyBody,
                    ),
                  ),
                ]
              : [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: atelierGutter(context),
                    ),
                    sliver: SliverList.separated(
                      itemCount: payouts.length,
                      separatorBuilder: (_, _) => DsGaps.vXs,
                      itemBuilder: (_, index) =>
                          WithdrawalTile(payout: payouts[index]),
                    ),
                  ),
                ],
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

/// Three lines on how a withdrawal travels — the question every new
/// boutique asks support.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final steps = [l10n.withdrawalHow1, l10n.withdrawalHow2, l10n.withdrawalHow3];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
      child: SellerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.withdrawalHowTitle,
              style: context.dsText.tileTitle.bold.tint(palette.ink),
            ),
            DsGaps.vSm,
            for (final (index, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.gold.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: context.dsText.caption.bold.tint(palette.gold),
                      ),
                    ),
                    DsGaps.hSm,
                    Expanded(
                      child: Text(
                        step,
                        style: context.dsText.bodySmall
                            .tint(palette.ink)
                            .copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One request: its amount, its state, when, and where it went.
class WithdrawalTile extends StatelessWidget {
  const WithdrawalTile({super.key, required this.payout});

  final PendingPayout payout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final (label, tone, icon) = switch (payout.status) {
      PayoutStatus.pending => (
        l10n.earningsPayoutPending,
        DsBadgeTone.neutral,
        Icons.hourglass_top_rounded,
      ),
      PayoutStatus.approved => (
        l10n.earningsPayoutApproved,
        DsBadgeTone.info,
        Icons.local_shipping_outlined,
      ),
      PayoutStatus.paid => (
        l10n.payoutStatusPaid,
        DsBadgeTone.success,
        Icons.check_circle_outline_rounded,
      ),
      PayoutStatus.failed => (
        l10n.payoutStatusFailed,
        DsBadgeTone.sale,
        Icons.error_outline_rounded,
      ),
      PayoutStatus.cancelled => (
        l10n.payoutStatusCancelled,
        DsBadgeTone.neutral,
        Icons.block_rounded,
      ),
    };
    final when = payout.paidAt ?? payout.createdAt;
    return SellerPanel(
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.muted),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payout.net.format(),
                  style: context.dsText.tileTitle.bold.tint(palette.ink).tabular,
                ),
                if (payout.destination case final destination?)
                  Text(
                    destination,
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                if (when != null)
                  Text(
                    formatCalendarDate(l10n, when),
                    style: context.dsText.caption.tint(palette.muted),
                  ),
              ],
            ),
          ),
          DsBadge(label: label, tone: tone),
        ],
      ),
    );
  }
}
