import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/admin_finance/domain/entities/finance_overview.dart';

/// The one question this console exists to answer.
///
/// A marketplace can read its takings off any report. Only a double-entry book
/// can say whether the takings are *true* — so the screen opens with that and
/// nothing else. Green means debits equal credits and no account has drifted
/// from its own lines; anything else is stated plainly, with the discrepancy
/// shown rather than hidden behind a word like "issue".
class LedgerHealthBanner extends StatelessWidget {
  const LedgerHealthBanner({super.key, required this.overview});

  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final console = context.console;

    // Three states, in descending order of how alarming they are. An unbalanced
    // book outranks a drifted account: one means money was created, the other
    // means a cache disagrees with its own history.
    final (tone, title, detail) = !overview.balanced
        ? (
            _Tone.critical,
            l10n.financeNotBalanced,
            '${l10n.financeDiscrepancy}: ${overview.discrepancy.format()}',
          )
        : overview.findings.isNotEmpty
        ? (
            overview.hasCriticalFinding ? _Tone.critical : _Tone.warning,
            l10n.financeUnsound,
            l10n.financeFindings(overview.findings.length),
          )
        : (_Tone.good, l10n.financeSound, l10n.financeSoundHint);

    final toned = _tonePalette(context, tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: toned.background,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: toned.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The verdict, in the court's arch: the ledger is a room of the
              // house like any other, lit in the colour of its state.
              CourtArchMedallion(icon: toned.icon, color: toned.accent),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.dsText.screenTitle.displayFamily.bold
                          .tint(toned.accent),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      detail,
                      style: context.dsText.bodySmall.tint(console.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // The two totals that produced the verdict, so an operator can see
          // the arithmetic rather than trust a badge.
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Total(
                  label: l10n.financeTotalDebit,
                  amount: overview.totalDebit.format(),
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: console.line,
                margin: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
              ),
              Expanded(
                child: _Total(
                  label: l10n.financeTotalCredit,
                  amount: overview.totalCredit.format(),
                ),
              ),
            ],
          ),

          if (overview.findings.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.md),
            for (final finding in overview.findings.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      finding.kind.isCritical
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 14,
                      color: finding.kind.isCritical
                          ? console.critical
                          : console.caution,
                    ),
                    const SizedBox(width: DsSpacing.xs),
                    // Findings name account codes and uuids and are written
                    // for whoever debugs the ledger. Forced left-to-right so
                    // the identifiers and figures inside them do not scramble
                    // against the surrounding Arabic.
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          finding.detail,
                          style: context.dsText.caption.tint(console.muted).copyWith(height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  _Palette _tonePalette(BuildContext context, _Tone tone) {
    final console = context.console;
    final (accent, icon) = switch (tone) {
      _Tone.good => (console.positive, Icons.verified_rounded),
      _Tone.warning => (console.caution, Icons.warning_amber_rounded),
      _Tone.critical => (console.critical, Icons.error_rounded),
    };
    return _Palette(
      accent: accent,
      background: accent.withValues(alpha: 0.10),
      border: accent.withValues(alpha: 0.28),
      icon: icon,
    );
  }
}

enum _Tone { good, warning, critical }

class _Palette {
  const _Palette({
    required this.accent,
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color accent;
  final Color background;
  final Color border;
  final IconData icon;
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.dsText.caption.tint(palette.muted),
        ),
        DsGaps.vXxxs,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            amount,
            maxLines: 1,
            style: context.dsText.body.bold.tint(palette.ink),
          ),
        ),
      ],
    );
  }
}
