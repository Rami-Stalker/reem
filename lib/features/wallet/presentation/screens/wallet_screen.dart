import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../providers/wallet_provider.dart';
import '../widgets/loyalty_convert_card.dart';
import '../widgets/wallet_balance_card.dart';
import '../widgets/wallet_transaction_tile.dart';

/// Her store credit, and where every piaster of it came from.
///
/// Q41 asked for «سجل كامل لحركات المحفظة (إضافة، خصم، سبب العملية، التاريخ)»,
/// so the statement is the screen — the balance is a header on top of it, not
/// the whole page. Q42 keeps the balance non-withdrawable, which is why there
/// is no "withdraw" affordance anywhere here; the card says so plainly instead
/// of leaving her to discover it at checkout.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletNotifierProvider);
    final l10n = context.l10n;

    _listenForMessages(context, ref);

    return ReemScrollPage(
      onRefresh: () => ref.read(walletNotifierProvider.notifier).refresh(),
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.wallet),
        ),

        if (state.isLoading)
          const SliverToBoxAdapter(child: _WalletSkeleton())
        else ...[
          SliverToBoxAdapter(
            child: WalletBalanceCard(
              balance: state.summary?.balance,
              isRefreshing: state.isRefreshing,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.lg)),

          const SliverToBoxAdapter(child: LoyaltyConvertCard()),
          const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xl)),

          if (state.summary?.transactions.isEmpty ?? true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.walletEmptyTitle,
                  message: l10n.walletEmptyBody,
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg,
                  0,
                  DsSpacing.lg,
                  DsSpacing.md,
                ),
                child: Text(
                  l10n.walletStatement,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: DsTypography.bold,
                  ),
                ),
              ),
            ),
            SliverList.separated(
              itemCount: state.summary!.transactions.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: DsSpacing.xs),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.lg,
                ),
                child: WalletTransactionTile(
                  transaction: state.summary!.transactions[index],
                ),
              ),
            ),
          ],
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  /// Surfaces one-shot outcomes, then clears them so a rebuild does not repeat
  /// the same snackbar.
  void _listenForMessages(BuildContext context, WidgetRef ref) {
    ref.listen<WalletState>(walletNotifierProvider, (previous, next) {
      final message = _messageFor(context, next);
      if (message == null) return;

      DsSnackbar.show(
        context,
        message: message.text,
        type: message.isError
            ? DsSnackbarType.error
            : DsSnackbarType.success,
      );
      ref.read(walletNotifierProvider.notifier).acknowledge();
    });
  }

  _WalletMessage? _messageFor(BuildContext context, WalletState state) {
    final l10n = context.l10n;

    if (state.convertedPoints != null) {
      return _WalletMessage(
        l10n.loyaltyConverted(state.convertedPoints!),
        isError: false,
      );
    }
    if (state.serverError != null) {
      return _WalletMessage(state.serverError!, isError: true);
    }
    return switch (state.issue) {
      WalletIssue.offline => _WalletMessage(l10n.walletOffline, isError: true),
      WalletIssue.pointsMultipleOfTen => _WalletMessage(
        l10n.loyaltyNeedMultipleOfTen,
        isError: true,
      ),
      WalletIssue.notEnoughPoints => _WalletMessage(
        l10n.loyaltyNotEnoughPoints,
        isError: true,
      ),
      null => null,
    };
  }
}

class _WalletMessage {
  const _WalletMessage(this.text, {required this.isError});

  final String text;
  final bool isError;
}

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.box(height: 140, borderRadius: DsRadius.card),
            SizedBox(height: DsSpacing.lg),
            DsSkeleton.box(height: 96, borderRadius: DsRadius.card),
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

/// Arabic label for a movement source (Q41).
extension WalletMovementSourceL10n on WalletMovementSource {
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      WalletMovementSource.returnRefund => l10n.walletSourceRefund,
      WalletMovementSource.pointsConversion => l10n.walletSourcePoints,
      WalletMovementSource.adminCompensation => l10n.walletSourceCompensation,
      WalletMovementSource.customerTopUp => l10n.walletSourceTopUp,
      WalletMovementSource.campaignGift => l10n.walletSourceGift,
      WalletMovementSource.priceAdjustment => l10n.walletSourceAdjustment,
      WalletMovementSource.orderPayment => l10n.walletSourceOrder,
      WalletMovementSource.orderReversal => l10n.walletSourceOrderReversal,
      WalletMovementSource.unknown => l10n.walletSourceOther,
    };
  }
}
