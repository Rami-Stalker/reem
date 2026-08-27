import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/admin_finance/domain/entities/finance_overview.dart';

/// Where the money is, and whether there is enough of it.
///
/// Coverage leads: held minus owed is the one line that says whether the
/// platform could actually meet its obligations today. The individual accounts
/// follow, split into what is held and what is owed rather than mixed into one
/// list, because an operator reading this is checking a balance sheet even if
/// nobody calls it that.
class FinancePositionGrid extends StatelessWidget {
  const FinancePositionGrid({super.key, required this.positions});

  final FinancePositions positions;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final undercovered = positions.isUndercovered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(DsSpacing.lg),
          decoration: BoxDecoration(
            color: undercovered
                ? const Color(0xFFFEF1F1)
                : palette.surface,
            borderRadius: DsRadius.borderCard,
            border: Border.all(
              color: undercovered
                  ? const Color(0xFFF2C4C4)
                  : palette.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: l10n.financeHeld,
                      amount: positions.totalHeld,
                      accent: palette.ink,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: l10n.financeOwed,
                      amount: positions.totalOwed,
                      accent: palette.ink,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: l10n.financeCoverage,
                      amount: positions.coverage,
                      accent: undercovered
                          ? palette.critical
                          : palette.positive,
                      emphasise: true,
                    ),
                  ),
                ],
              ),
              if (undercovered) ...[
                const SizedBox(height: DsSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: palette.critical,
                    ),
                    const SizedBox(width: DsSpacing.xxs),
                    Expanded(
                      child: Text(
                        l10n.financeCoverageShort,
                        style: TextStyle(
                          fontSize: DsTypography.labelSmall,
                          fontWeight: DsTypography.semiBold,
                          color: palette.critical,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DsSpacing.md),

        LayoutBuilder(
          builder: (context, constraints) {
            // Two columns on anything narrower than a laptop, four above it.
            final columns = constraints.maxWidth > 900 ? 4 : 2;
            // A tile holds a label and one number, so its height is fixed by
            // the type — the ratio has to follow the column width rather than
            // be a single figure that leaves half the box empty at one size.
            final tileWidth =
                (constraints.maxWidth - DsSpacing.sm * (columns - 1)) / columns;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: DsSpacing.sm,
              mainAxisSpacing: DsSpacing.sm,
              childAspectRatio: tileWidth / 88,
              children: [
                _Tile(
                  label: l10n.financePlatformCash,
                  amount: positions.platformCash,
                  icon: Icons.savings_outlined,
                ),
                _Tile(
                  label: l10n.financeCourierInTransit,
                  amount: positions.courierInTransit,
                  icon: Icons.local_shipping_outlined,
                ),
                _Tile(
                  label: l10n.financeGatewayReceivable,
                  amount: positions.gatewayReceivable,
                  icon: Icons.credit_card_outlined,
                ),
                _Tile(
                  label: l10n.financeCommissionRevenue,
                  amount: positions.commissionRevenue,
                  icon: Icons.trending_up_rounded,
                ),
                _Tile(
                  label: l10n.financeSellerPayable,
                  amount: positions.sellerPayable,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _Tile(
                  label: l10n.financeSellerEscrow,
                  amount: positions.sellerEscrow,
                  icon: Icons.hourglass_bottom_rounded,
                ),
                _Tile(
                  label: l10n.financeCustomerWallets,
                  amount: positions.customerWallets,
                  icon: Icons.wallet_outlined,
                ),
                _Tile(
                  label: l10n.financeDisputeHeld,
                  amount: positions.disputeHeld,
                  icon: Icons.gavel_rounded,
                  // Frozen money is the tile worth noticing, and only when
                  // there is any.
                  isAlert: !positions.disputeHeld.isZero,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.accent,
    this.emphasise = false,
  });

  final String label;
  final Money amount;
  final Color accent;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: DsTypography.labelSmall,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            amount.format(),
            maxLines: 1,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: emphasise
                  ? DsTypography.titleMedium
                  : DsTypography.bodyLarge,
              fontWeight: DsTypography.bold,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.amount,
    required this.icon,
    this.isAlert = false,
  });

  final String label;
  final Money amount;
  final IconData icon;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final accent = isAlert ? palette.caution : palette.muted;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF8EC) : palette.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(
          color: isAlert ? const Color(0xFFF0DCB0) : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: DsSpacing.xxs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DsTypography.labelSmall,
                    fontWeight: DsTypography.semiBold,
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
                fontSize: DsTypography.bodyLarge,
                fontWeight: DsTypography.bold,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
