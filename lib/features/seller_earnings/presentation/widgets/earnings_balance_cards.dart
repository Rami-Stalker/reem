import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';

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
      padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
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

    // Her balance on the atelier's cloth, with the stitch round its edge —
    // the same cloth as the home's takings, because it is the same money.
    return AtelierHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.earningsAvailable,
                  style: context.dsText.labelMedium.bold
                      .tint(DsColors.onMedia)
                      .copyWith(letterSpacing: 0.6),
                ),
              ),
              if (isRefreshing)
                DsLoadingIndicator.inline(color: DsColors.onMedia),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              amount.format(),
              maxLines: 1,
              style: context.dsText.hero.displayFamily.bold
                  .tint(DsColors.gold200)
                  .copyWith(height: 1.1),
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_repeat_rounded,
                size: 15,
                color: DsColors.onMediaMuted,
              ),
              const SizedBox(width: DsSpacing.xxs),
              Text(
                l10n.earningsAvailableHint,
                style: context.dsText.caption.tint(DsColors.onMediaMuted),
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
                  style: context.dsText.caption.bold.tint(accent),
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
              style: context.dsText.tileTitle.bold.tint(colors.onSurface),
            ),
          ),
          DsGaps.vXxxs,
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption
                .tint(colors.onSurfaceVariant)
                .copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}
