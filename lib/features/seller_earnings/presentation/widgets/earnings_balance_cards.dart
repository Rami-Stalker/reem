import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/shared/value_objects/money.dart';
import '../../domain/entities/seller_earnings.dart';

/// The seller's three balances.
///
/// «جاهز للسحب» leads because it is the number she came for; escrow and
/// frozen sit beneath it as smaller tiles. They are deliberately never added
/// together — a single "balance" would be the figure she quotes back in an
/// argument, and it would be wrong in three different ways at once.
class EarningsBalanceCards extends StatelessWidget {
  const EarningsBalanceCards({
    super.key,
    required this.earnings,
    this.isRefreshing = false,
  });

  final SellerEarnings earnings;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        children: [
          _AvailableCard(
            amount: earnings.availableForPayout,
            isRefreshing: isRefreshing,
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SecondaryTile(
                  label: l10n.earningsHeld,
                  hint: l10n.earningsHeldHint,
                  amount: earnings.heldInEscrow,
                  icon: Icons.hourglass_bottom_rounded,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: _SecondaryTile(
                  label: l10n.earningsFrozen,
                  hint: l10n.earningsFrozenHint,
                  amount: earnings.frozenInDisputes,
                  icon: Icons.gavel_rounded,
                  // Frozen money is the one figure worth alarming about, and
                  // only when there is some.
                  isAlert: earnings.hasFrozenFunds,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({required this.amount, required this.isRefreshing});

  final Money amount;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.xl),
      decoration: BoxDecoration(
        // Her balance, in her palette. This card used to wear the buyer's
        // signature rose.
        gradient: palette.headerGradient,
        borderRadius: DsRadius.borderCard,
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
              Expanded(
                child: Text(
                  l10n.earningsAvailable,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: DsTypography.labelMedium,
                    fontWeight: DsTypography.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (isRefreshing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              amount.format(),
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: DsTypography.fontFamilyDisplay,
                fontFamilyFallback: DsTypography.displayFallback,
                fontSize: 40,
                fontWeight: DsTypography.bold,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_repeat_rounded,
                size: 15,
                color: Colors.white70,
              ),
              const SizedBox(width: DsSpacing.xxs),
              Text(
                l10n.earningsAvailableHint,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: DsTypography.labelSmall,
                  fontWeight: DsTypography.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecondaryTile extends StatelessWidget {
  const _SecondaryTile({
    required this.label,
    required this.hint,
    required this.amount,
    required this.icon,
    this.isAlert = false,
  });

  final String label;
  final String hint;
  final Money amount;
  final IconData icon;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final accent = isAlert ? colors.warning : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: isAlert ? colors.warningContainer : colors.surfaceElevated,
        borderRadius: DsRadius.borderCard,
        border: Border.all(
          color: isAlert
              ? colors.warning.withValues(alpha: 0.4)
              : colors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: DsSpacing.xxs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DsTypography.labelSmall,
                    fontWeight: DsTypography.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              amount.format(),
              maxLines: 1,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.titleSmall,
                fontWeight: DsTypography.bold,
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              color: colors.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
