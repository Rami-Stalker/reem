import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money.dart';

/// The balance, set on the platform's signature gradient.
///
/// It carries one line of small print on purpose: Q42 makes this credit
/// spendable inside Reem and **not** withdrawable as cash, and the honest
/// place to say so is next to the figure — not in a terms page she finds after
/// trying to cash out.
class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balance,
    this.isRefreshing = false,
  });

  final Money? balance;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amount = balance ?? Money.zeroSyp;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DsSpacing.xl),
        decoration: BoxDecoration(
          gradient: CustomerExperience.signatureGradient,
          borderRadius: DsRadius.borderCard,
          boxShadow: context.boutique.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.walletBalance,
                    style: context.dsText.labelMedium.bold.tint(DsColors.onMedia).copyWith(letterSpacing: 0.6),
                  ),
                ),
                if (isRefreshing)
                  DsLoadingIndicator.inline(color: DsColors.onMedia),
              ],
            ),
            const SizedBox(height: DsSpacing.sm),

            // The figure itself, in the display face — the one thing she came
            // to the screen to read.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                amount.format(),
                maxLines: 1,
                style: context.dsText.hero.tint(DsColors.onMedia).copyWith(height: 1.1),
              ),
            ),
            const SizedBox(height: DsSpacing.md),

            // Q42, stated plainly.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 15,
                  color: DsColors.onMediaMuted,
                ),
                const SizedBox(width: DsSpacing.xxs),
                Flexible(
                  child: Text(
                    l10n.walletNotWithdrawable,
                    style: context.dsText.caption.tint(DsColors.onMediaMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
