import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:ohara/features/seller_earnings/presentation/providers/seller_earnings_provider.dart';

/// «التقارير المالية» — her money month by month.
///
/// Not the statement (that is «أرباحي», one movement at a time) and not the
/// withdrawals («مركز السحب»): the view an accountant asks for. Sales, what
/// the platform kept, what is hers, what was reversed and what was paid out,
/// for each month and for the whole span.
class SellerFinancialReportsScreen extends ConsumerStatefulWidget {
  const SellerFinancialReportsScreen({super.key});

  @override
  ConsumerState<SellerFinancialReportsScreen> createState() =>
      _SellerFinancialReportsScreenState();
}

class _SellerFinancialReportsScreenState
    extends ConsumerState<SellerFinancialReportsScreen> {
  static const _spans = [3, 6, 12];
  int _months = 6;

  /// The month the chart has picked out; null for the newest.
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = ref.watch(sellerReportProvider(_months));
    final gutter = atelierGutter(context);

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(sellerReportProvider(_months)),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.receipt_long_rounded,
          title: l10n.sellerFinancialReports,
          subtitle: l10n.reportsSubtitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverToBoxAdapter(child: _spanPicker(context)),
        ),
        DsGaps.sliverMd,
        ...report.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            ),
          ],
          error: (error, _) => [
            SliverToBoxAdapter(
              child: DsErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(sellerReportProvider(_months)),
              ),
            ),
          ],
          data: (data) => data.isEmpty
              ? [
                  SliverToBoxAdapter(
                    child: DsEmptyState(
                      icon: Icons.insights_outlined,
                      title: l10n.reportsEmpty,
                      message: l10n.reportsEmptyBody,
                    ),
                  ),
                ]
              : _content(context, data, gutter),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  Widget _spanPicker(BuildContext context) {
    final l10n = context.l10n;
    final chips = [
      for (final span in _spans)
        ChoiceChip(
          label: Text(
            span == 12 ? l10n.reportsRangeYear : l10n.reportsRangeMonths(span),
          ),
          selected: span == _months,
          onSelected: (_) => setState(() {
            _months = span;
            _selected = null;
          }),
        ),
    ];
    return Wrap(spacing: DsSpacing.xs, children: chips);
  }

  List<Widget> _content(
    BuildContext context,
    SellerReport report,
    double gutter,
  ) {
    final l10n = context.l10n;
    final selected = report.months.firstWhere(
      (m) => m.month == _selected,
      orElse: () => report.months.first,
    );
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        sliver: SliverList.list(
          children: [
            _Totals(totals: report.totals),
            DsGaps.vLg,
            AtelierHeading(title: l10n.reportsNetByMonth),
            DsGaps.vSm,
            SellerPanel(
              child: _NetChart(
                months: report.months.reversed.toList(),
                selected: selected.month,
                onSelect: (month) => setState(() => _selected = month),
              ),
            ),
            DsGaps.vLg,
            AtelierHeading(title: l10n.reportsMonths),
            DsGaps.vSm,
          ],
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        sliver: SliverList.separated(
          itemCount: report.months.length,
          separatorBuilder: (_, _) => DsGaps.vXs,
          itemBuilder: (_, index) {
            final month = report.months[index];
            return _MonthCard(
              month: month,
              expanded: month.month == selected.month,
              onTap: () => setState(() => _selected = month.month),
            );
          },
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(gutter, DsSpacing.lg, gutter, 0),
        sliver: SliverToBoxAdapter(
          child: Text(
            l10n.reportsNote,
            style: context.dsText.caption.tint(context.atelier.muted),
          ),
        ),
      ),
    ];
  }
}

/// The span's headline: her net, then how it was made.
class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final SellerReportMonth totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return SellerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reportsNet,
            style: context.dsText.caption.tint(palette.muted),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              totals.net.format(),
              style: context.dsText.screenTitle.bold.tint(palette.gold).tabular,
            ),
          ),
          Text(
            l10n.reportsOrders(totals.orders),
            style: context.dsText.caption.tint(palette.muted),
          ),
          DsGaps.vMd,
          Divider(height: 1, color: palette.line),
          DsGaps.vMd,
          _Figure(label: l10n.reportsGross, amount: totals.gross),
          _Figure(
            label: l10n.reportsCommission,
            amount: totals.commission,
            deduction: true,
          ),
          if (!totals.platformFees.isZero)
            _Figure(
              label: l10n.reportsFees,
              amount: totals.platformFees,
              deduction: true,
            ),
          if (!totals.reversed.isZero)
            _Figure(
              label: l10n.reportsReversed,
              amount: totals.reversed,
              deduction: true,
            ),
          _Figure(
            label: l10n.reportsPaidOut,
            amount: totals.paidOut,
            emphasise: true,
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    this.deduction = false,
    this.emphasise = false,
  });

  final String label;
  final Money amount;
  final bool deduction;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final style = emphasise
        ? context.dsText.body.bold.tint(palette.ink)
        : context.dsText.body.tint(palette.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.dsText.bodySmall.tint(palette.muted),
            ),
          ),
          Text(
            '${deduction && !amount.isZero ? '−' : ''}${amount.format()}',
            style: style.tabular,
          ),
        ],
      ),
    );
  }
}

/// Net per month as bars, oldest on the start side. A tap picks a month.
class _NetChart extends StatelessWidget {
  const _NetChart({
    required this.months,
    required this.selected,
    required this.onSelect,
  });

  final List<SellerReportMonth> months;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const double _height = 140;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final peak = months.fold<double>(
      0,
      (max, m) => m.net.approximateValue > max ? m.net.approximateValue : max,
    );
    return SizedBox(
      height: _height + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final month in months)
            Expanded(
              child: Semantics(
                button: true,
                selected: month.month == selected,
                label:
                    '${formatMonthYear(l10n, month.month)}: ${month.net.format()}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(month.month),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: DsMotion.moderate,
                        curve: DsMotion.emphasized,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.xxs,
                        ),
                        height: peak <= 0
                            ? 4
                            : 4 +
                                  (_height - 4) *
                                      (month.net.approximateValue.clamp(
                                            0,
                                            peak,
                                          ) /
                                          peak),
                        decoration: BoxDecoration(
                          color: month.month == selected
                              ? palette.gold
                              : palette.gold.withValues(alpha: 0.28),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(DsRadius.sm),
                          ),
                        ),
                      ),
                      DsGaps.vXs,
                      Text(
                        formatMonthShort(l10n, month.month),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: context.dsText.caption.tint(
                          month.month == selected ? palette.ink : palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One month: its net on the line, the breakdown when opened.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.expanded,
    required this.onTap,
  });

  final SellerReportMonth month;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return SellerPanel(
      onTap: onTap,
      child: AnimatedSize(
        duration: DsMotion.normal,
        curve: DsMotion.standard,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMonthYear(l10n, month.month),
                        style: context.dsText.tileTitle.bold.tint(palette.ink),
                      ),
                      Text(
                        month.isEmpty
                            ? l10n.reportsNoActivity
                            : l10n.reportsOrders(month.orders),
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  month.net.format(),
                  style: context.dsText.body.bold.tint(palette.ink).tabular,
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: palette.muted,
                ),
              ],
            ),
            if (expanded && !month.isEmpty) ...[
              DsGaps.vSm,
              Divider(height: 1, color: palette.line),
              DsGaps.vSm,
              _Figure(label: l10n.reportsGross, amount: month.gross),
              _Figure(
                label: l10n.reportsCommission,
                amount: month.commission,
                deduction: true,
              ),
              if (!month.platformFees.isZero)
                _Figure(
                  label: l10n.reportsFees,
                  amount: month.platformFees,
                  deduction: true,
                ),
              if (month.reversedOrders > 0)
                _Figure(
                  label:
                      '${l10n.reportsReversed} (${month.reversedOrders})',
                  amount: month.reversed,
                  deduction: true,
                ),
              _Figure(
                label: l10n.reportsNet,
                amount: month.net,
                emphasise: true,
              ),
              _Figure(label: l10n.reportsPaidOut, amount: month.paidOut),
            ],
          ],
        ),
      ),
    );
  }
}
