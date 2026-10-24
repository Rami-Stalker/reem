import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/admin_finance/domain/entities/finance_overview.dart';

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
        CourtPanel(
          padding: DsSpacing.paddingLg,
          accent: undercovered ? palette.critical : null,
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
                        style: context.dsText.caption.semibold.tint(
                          palette.critical,
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

        CourtFigureRow(
          minTileWidth: 200,
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
        Text(label, style: context.dsText.caption.tint(palette.muted)),
        DsGaps.vXxxs,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            amount.format(),
            maxLines: 1,
            style:
                (emphasise ? context.dsText.metric : context.dsText.metricSmall)
                    .displayFamily
                    .tint(accent),
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
    return CourtFigure(
      label: label,
      value: amount.format(),
      icon: icon,
      accent: isAlert ? palette.caution : palette.primary,
    );
  }
}
