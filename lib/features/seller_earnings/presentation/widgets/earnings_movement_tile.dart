import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../domain/entities/seller_earnings.dart';

/// One line of the seller's statement.
///
/// The movement type is shown rather than the raw description, because a
/// seller reading her statement wants to know *what happened* — a sale, a
/// release, a freeze — before she reads which order it was.
class EarningsMovementTile extends StatelessWidget {
  const EarningsMovementTile({super.key, required this.movement});

  final EarningsMovement movement;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final incoming = movement.isIncoming;

    // A freeze is neither a gain nor a loss — it is a hold, and colouring it
    // like a payout would tell her she lost money she still owns.
    final isHold =
        movement.type == EarningsMovementType.disputeHeld ||
        movement.account == EarningsAccount.disputeHeld;

    // A transfer between her own accounts is not income either, so it stays
    // neutral rather than borrowing the green of money arriving.
    final accent = isHold
        ? colors.warning
        : movement.isTransfer
        ? colors.onSurfaceVariant
        : (incoming ? colors.success : colors.onSurface);

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
              color: isHold
                  ? colors.warningContainer
                  : (!movement.isTransfer && incoming
                        ? colors.successContainer
                        : colors.surfaceVariant),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon(isHold, incoming), size: 18, color: accent),
          ),
          const SizedBox(width: DsSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.bodyMedium,
                    fontWeight: DsTypography.medium,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
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

          Text(
            // No sign on a transfer: nothing entered or left her balance.
            movement.isSigned
                ? '${incoming ? '+' : '−'}${movement.amount.absolute.format()}'
                : movement.amount.absolute.format(),
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.bodyMedium,
              fontWeight: DsTypography.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(bool isHold, bool incoming) {
    if (isHold) return Icons.lock_outline_rounded;
    if (movement.isTransfer) return Icons.swap_horiz_rounded;
    return switch (movement.type) {
      EarningsMovementType.payoutPaid => Icons.account_balance_rounded,
      EarningsMovementType.escrowReleased => Icons.lock_open_rounded,
      EarningsMovementType.commissionEarned => Icons.shopping_bag_outlined,
      EarningsMovementType.reversal => Icons.undo_rounded,
      _ => incoming
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded,
    };
  }

  String _label(BuildContext context) {
    final l10n = context.l10n;
    return switch (movement.type) {
      EarningsMovementType.commissionEarned => l10n.earningsMoveSale,
      EarningsMovementType.escrowReleased => l10n.earningsMoveReleased,
      EarningsMovementType.payoutPaid => l10n.earningsMovePayout,
      EarningsMovementType.disputeHeld => l10n.earningsMoveFrozen,
      EarningsMovementType.disputeReleased => l10n.earningsMoveDisputeDone,
      EarningsMovementType.refundIssued ||
      EarningsMovementType.returnSettled => l10n.earningsMoveRefund,
      EarningsMovementType.reversal => l10n.earningsMoveReversal,
      EarningsMovementType.unknown => l10n.earningsMoveOther,
    };
  }

  String _when(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return toWesternDigits(
      DateFormat.yMMMd(locale).add_jm().format(movement.occurredAt),
    );
  }
}
