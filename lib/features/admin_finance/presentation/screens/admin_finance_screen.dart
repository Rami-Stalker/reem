import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/arabic_numerals.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:reem/features/admin_finance/domain/entities/finance_overview.dart';
import 'package:reem/features/admin_finance/presentation/providers/admin_finance_provider.dart';
import 'package:reem/features/admin_finance/presentation/widgets/finance_position_grid.dart';
import 'package:reem/features/admin_finance/presentation/widgets/ledger_health_banner.dart';

/// The finance console.
///
/// Ordered by what an operator needs in the order they need it: is the book
/// sound, where is the money, what needs a person today, and only then the
/// full trial balance for anyone who wants to check the working.
class AdminFinanceScreen extends ConsumerStatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  ConsumerState<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends ConsumerState<AdminFinanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminFinanceNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final state = ref.watch(adminFinanceNotifierProvider);
    final overview = state.overview;

    _listenForMessages();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminFinance,
            subtitle: l10n.adminFinanceSubtitle,
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () =>
                    ref.read(adminFinanceNotifierProvider.notifier).refresh(),
                icon: state.isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),

          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(DsSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (overview == null)
            Padding(
              padding: const EdgeInsets.all(DsSpacing.xl),
              child: Text(
                state.error ?? '',
                style: context.dsText.body.tint(palette.critical),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.xl,
                DsSpacing.xxxs,
                DsSpacing.xl,
                DsSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LedgerHealthBanner(overview: overview),
                  const SizedBox(height: DsSpacing.xl),

                  _Section(title: l10n.financePositions),
                  FinancePositionGrid(positions: overview.positions),
                  const SizedBox(height: DsSpacing.xl),

                  _CourierCashSection(overview: overview),
                  const SizedBox(height: DsSpacing.xl),

                  _OverdueDisputesSection(overview: overview),
                  const SizedBox(height: DsSpacing.xl),

                  _FxSection(
                    overview: overview,
                    isSyncing: state.isSyncingRate,
                    onSync: () => ref
                        .read(adminFinanceNotifierProvider.notifier)
                        .syncExchangeRate(),
                  ),
                  const SizedBox(height: DsSpacing.xl),

                  _Section(title: l10n.financeTrialBalance),
                  _TrialBalanceTable(rows: overview.rows),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _listenForMessages() {
    ref.listen<AdminFinanceState>(adminFinanceNotifierProvider, (
      previous,
      next,
    ) {
      final message = next.error ?? next.notice;
      if (message == null || message.isEmpty) return;

      DsSnackbar.show(
        context,
        message: message,
        type: next.error != null
            ? DsSnackbarType.error
            : DsSnackbarType.info,
      );
      ref.read(adminFinanceNotifierProvider.notifier).acknowledge();
    });
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Text(
        title,
        style: context.dsText.cardTitle.bold.tint(palette.ink),
      ),
    );
  }
}

/// Q56 — cash a courier collected and has not handed over.
class _CourierCashSection extends StatelessWidget {
  const _CourierCashSection({required this.overview});

  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Section(title: l10n.financeCourierCash)),
            if (overview.courierCash.isNotEmpty)
              Text(
                overview.courierCashTotal.format(),
                style: context.dsText.body.bold.tint(palette.ink),
              ),
          ],
        ),
        if (overview.courierCash.isEmpty)
          _EmptyNote(text: l10n.financeCourierCashEmpty)
        else
          for (final position in overview.courierCash)
            _Row(
              title: position.courierName ?? '—',
              subtitle: position.courierPhone,
              trailing: position.outstanding.format(),
              icon: Icons.local_shipping_outlined,
            ),
      ],
    );
  }
}

/// Q107 — disputes past their 3/7 working-day clock.
class _OverdueDisputesSection extends StatelessWidget {
  const _OverdueDisputesSection({required this.overview});

  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(title: l10n.financeOverdueDisputes),
        if (overview.overdueDisputes.isEmpty)
          _EmptyNote(text: l10n.financeNoOverdue)
        else
          for (final dispute in overview.overdueDisputes)
            _Row(
              title: '${dispute.number} — ${dispute.subject}',
              subtitle: l10n.financeOverdueBy(dispute.daysOverdue(now)),
              trailing: dispute.frozenAmount.format(),
              icon: Icons.gavel_rounded,
              isAlert: true,
            ),
      ],
    );
  }
}

class _FxSection extends StatelessWidget {
  const _FxSection({
    required this.overview,
    required this.isSyncing,
    required this.onSync,
  });

  final FinanceOverview overview;
  final bool isSyncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final fx = overview.fx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Section(title: l10n.financeFx)),
            TextButton.icon(
              onPressed: isSyncing ? null : onSync,
              icon: isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 16),
              label: Text(l10n.financeFxSync),
            ),
          ],
        ),
        if (fx == null)
          _EmptyNote(text: l10n.financeFxNone)
        else
          Container(
            padding: const EdgeInsets.all(DsSpacing.lg),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: DsRadius.borderCard,
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _FxFigure(
                    label: '${l10n.financeFxRate} (${fx.foreignCurrency})',
                    value: '${fx.rate}  ·  ${fx.rateSource}',
                  ),
                ),
                Expanded(
                  child: _FxFigure(
                    label: l10n.financeFxExposure,
                    value: fx.netExposure.format(),
                  ),
                ),
                Expanded(
                  child: _FxFigure(
                    label: l10n.financeFxResult,
                    value: fx.netResult.format(),
                    // A loss is the case worth colouring.
                    accent: fx.netResult.isNegative
                        ? palette.critical
                        : palette.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FxFigure extends StatelessWidget {
  const _FxFigure({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;

  /// Null means "the console's default ink" — a default argument cannot read
  /// the theme, so the fallback is applied here.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final ink = accent ?? palette.ink;
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
            value,
            maxLines: 1,
            style: context.dsText.body.bold.tint(ink),
          ),
        ),
      ],
    );
  }
}

/// The full account listing, for anyone who wants to check the working.
class _TrialBalanceTable extends StatelessWidget {
  const _TrialBalanceTable({required this.rows});

  final List<TrialBalanceRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.lg,
              vertical: DsSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(DsRadius.card),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    l10n.financeAccount,
                    style: _headerStyle(context, palette.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.financeTotalDebit,
                    textAlign: TextAlign.end,
                    style: _headerStyle(context, palette.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.financeTotalCredit,
                    textAlign: TextAlign.end,
                    style: _headerStyle(context, palette.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.financeBalance,
                    textAlign: TextAlign.end,
                    style: _headerStyle(context, palette.muted),
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.lg,
                vertical: DsSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.bodySmall.semibold.tint(palette.ink),
                        ),
                        // Per-party accounts show whose they are, shortened —
                        // the full uuid helps nobody read a table.
                        if (row.ownerId != null)
                          Text(
                            row.ownerId!.substring(0, 8),
                            style: context.dsText.micro.tint(palette.muted),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: _Cell(row.debit.format())),
                  Expanded(child: _Cell(row.credit.format())),
                  Expanded(
                    child: _Cell(
                      row.balance.format(),
                      // A negative liability is the shape of an over-release.
                      accent: row.balance.isNegative
                          ? palette.critical
                          : palette.ink,
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The column headers of the ledger table. Takes the context because the
  /// role comes off the theme, not a frozen constant.
  static TextStyle _headerStyle(BuildContext context, Color color) =>
      context.dsText.caption.bold.tint(color);
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    this.accent,
    this.bold = false,
  });

  final String text;

  /// Null means "the console's default ink" — resolved at build time, because
  /// a default argument cannot read the theme.
  final Color? accent;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.dsText.bodySmall
          .tint(accent ?? context.console.ink)
          .copyWith(fontWeight: bold ? DsTypography.bold : DsTypography.regular),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.trailing,
    required this.icon,
    this.subtitle,
    this.isAlert = false,
  });

  final String title;
  final String? subtitle;
  final String trailing;
  final IconData icon;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.xs),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: isAlert ? context.toneContainer(DsTone.caution) : palette.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(
          color: isAlert ? context.toneColor(DsTone.caution).withValues(alpha: 0.4) : palette.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isAlert ? palette.caution : palette.muted,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.bodySmall.semibold.tint(palette.ink),
                ),
                if (subtitle != null)
                  Text(
                    toWesternDigits(subtitle!),
                    style: context.dsText.caption.tint(palette.muted),
                  ),
              ],
            ),
          ),
          Text(
            trailing,
            style: context.dsText.bodySmall.bold.tint(palette.ink),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(DsRadius.lg),
      ),
      child: Text(
        text,
        style: context.dsText.bodySmall.tint(palette.muted),
      ),
    );
  }
}

/// Unused today, kept so the table can show dates if it grows a column.
// ignore: unused_element
String _formatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).languageCode;
  return toWesternDigits(DateFormat.yMMMd(locale).format(value));
}
