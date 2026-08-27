import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../domain/entities/wallet_transaction.dart';

/// One line of the statement.
///
/// Direction is carried by colour *and* a sign *and* an icon — Q92 asks not to
/// rely on colour alone to distinguish states, and a credit reading as a debit
/// is exactly the sort of mistake that costs trust in a money screen.
class WalletTransactionTile extends StatelessWidget {
  const WalletTransactionTile({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isCredit = transaction.isCredit;
    final accent = isCredit ? colors.success : colors.onSurface;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit
                  ? colors.successContainer
                  : colors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: DsSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.bodyMedium,
                    fontWeight: DsTypography.medium,
                    color: colors.onSurface,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                // Date only. The source label would repeat what `reason`
                // already says in Arabic — «تحويل نقاط ولاء» under «تحويل ١٠٠
                // نقطة ولاء» is noise, and it pushed the line to two rows.
                Text(
                  _when(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DsTypography.labelSmall,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // The sign is explicit rather than implied by the colour.
                '${isCredit ? '+' : '−'}${transaction.amount.absolute.format()}',
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: DsTypography.bodyMedium,
                  fontWeight: DsTypography.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 2),
              // The running balance, so a statement reads down the page
              // without her adding anything up (Q41).
              Text(
                transaction.balanceAfter.format(),
                style: TextStyle(
                  fontSize: DsTypography.labelSmall,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _when(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final formatted = DateFormat.yMMMd(
      locale,
    ).add_jm().format(transaction.createdAt);
    // Arabic month names, Western digits — matching the money beside it.
    return toWesternDigits(formatted);
  }
}
