import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `intl` exports a TextDirection of its own; the one meant here is the
// framework's, used to pin document codes left-to-right.
import 'package:intl/intl.dart' hide TextDirection;

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/core/utils/arabic_numerals.dart';
import 'package:ohara/features/invoices/domain/entities/invoice.dart';
import 'package:ohara/features/invoices/presentation/providers/invoices_provider.dart';

/// Q51 — one invoice document, laid out to be read and quoted.
///
/// Deliberately looks like a document rather than a screen: a bordered sheet
/// with a header, lines and totals, because this is the thing she screenshots
/// and sends to someone. It states plainly that it is commercial and not
/// fiscal (Q55 P1) so nobody presents it as a tax invoice.
class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(invoiceDetailProvider(invoiceId));

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(invoiceDetailProvider(invoiceId)),
      slivers: [
        PremiumAppBar(title: l10n.invoice, showBack: true),
        async.when(
          loading: () =>
              const SliverToBoxAdapter(child: _InvoiceSkeleton()),
          error: (error, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
              ),
            ),
          ),
          data: (invoice) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              child: _Document(invoice: invoice),
            ),
          ),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _Document extends StatelessWidget {
  const _Document({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.isSellerCopy
                          ? l10n.invoiceSellerCopy
                          : l10n.invoiceCustomerCopy,
                      style: context.dsText.sectionTitle.displayFamily.bold.tint(colors.onSurface),
                    ),
                    const SizedBox(height: DsSpacing.xxs),
                    _Meta(
                      label: l10n.invoiceNumber,
                      value: invoice.number,
                      isCode: true,
                    ),
                    _Meta(
                      label: l10n.invoiceOrderNumber,
                      value: invoice.sellerOrderNumber ?? invoice.orderNumber,
                      isCode: true,
                    ),
                    _Meta(
                      label: l10n.invoiceIssuedAt,
                      value: _formatDate(context, invoice.issuedAt),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.receipt_long_rounded,
                size: 28,
                color: colors.primary,
              ),
            ],
          ),

          if (invoice.recipient != null) ...[
            const SizedBox(height: DsSpacing.lg),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: DsSpacing.md),
            Text(
              l10n.invoiceBilledTo,
              style: DsTypography.overline(colors.primary),
            ),
            const SizedBox(height: DsSpacing.xxs),
            Text(
              invoice.recipient!.name,
              style: context.dsText.body.semibold.tint(colors.onSurface),
            ),
            Text(
              invoice.recipient!.fullAddress,
              style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
            ),
          ],

          // ── Lines ────────────────────────────────────────────────────
          const SizedBox(height: DsSpacing.lg),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: DsSpacing.md),
          Text(
            l10n.invoiceItems,
            style: DsTypography.overline(colors.primary),
          ),
          const SizedBox(height: DsSpacing.sm),
          for (final line in invoice.lines) _Line(line: line),

          // ── Totals ───────────────────────────────────────────────────
          const SizedBox(height: DsSpacing.md),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: DsSpacing.md),

          _Total(label: l10n.invoiceSubtotal, amount: invoice.itemsSubtotal),
          if (invoice.hasDiscount)
            _Total(
              label: invoice.couponCode == null
                  ? l10n.invoiceDiscount
                  : '${l10n.invoiceDiscount} · ${invoice.couponCode}',
              amount: invoice.discountTotal,
              isDeduction: true,
            ),
          if (!invoice.shippingTotal.isZero)
            _Total(label: l10n.invoiceShipping, amount: invoice.shippingTotal),

          const SizedBox(height: DsSpacing.xs),
          _Total(
            label: l10n.invoiceTotal,
            amount: invoice.grandTotal,
            emphasise: true,
          ),

          // Q50 — only on the seller's copy. On the customer's it would just
          // obscure the figure she actually paid.
          if (invoice.showsCommission) ...[
            const SizedBox(height: DsSpacing.sm),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: DsSpacing.sm),
            _Total(
              label: l10n.invoiceCommission,
              amount: invoice.commissionAmount!,
              isDeduction: true,
            ),
            if (invoice.sellerNet != null)
              _Total(
                label: l10n.invoiceSellerNet,
                amount: invoice.sellerNet!,
                emphasise: true,
              ),
          ],

          // Q55 P1 — the client stated no fiscal requirement, so the document
          // says what it is rather than letting anyone assume otherwise.
          const SizedBox(height: DsSpacing.lg),
          Text(
            l10n.invoiceNoTax,
            style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, this.isCode = false});

  final String label;
  final String value;
  final bool isCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.xxxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: context.dsText.caption.tint(colors.onSurfaceVariant),
          ),
          if (isCode)
            // Document numbers get read out and typed in; left-to-right keeps
            // their parts in the order they were printed.
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                value,
                style: context.dsText.caption.bold.tint(colors.onSurface),
              ),
            )
          else
            Text(
              value,
              style: context.dsText.caption.semibold.tint(colors.onSurface),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.title,
                  style: context.dsText.bodySmall.semibold.tint(colors.onSurface).copyWith(height: 1.4),
                ),
                Text(
                  [
                    if (line.variant != null) line.variant!,
                    if (line.seller != null) line.seller!,
                    '${context.l10n.invoiceQuantity} ${toWesternDigits('${line.quantity}')}',
                  ].join(' · '),
                  style: context.dsText.caption.tint(colors.onSurfaceVariant),
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
                line.lineTotal.format(),
                style: context.dsText.bodySmall.bold.tint(colors.onSurface),
              ),
              // The discount is an amount taken off, not a former price — a
              // struck-through figure would read as "was 50,000", which is a
              // different and wrong claim.
              if (line.isDiscounted)
                Text(
                  '−${line.unitDiscount.format()}',
                  style: context.dsText.caption.semibold.tint(colors.successInk),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.amount,
    this.isDeduction = false,
    this.emphasise = false,
  });

  final String label;
  final Money amount;
  final bool isDeduction;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasise
                  ? context.dsText.body.bold
                  : context.dsText.cardSubtitle,
            ),
          ),
          Text(
            '${isDeduction ? '−' : ''}${amount.format()}',
            style: (emphasise
                    ? context.dsText.price
                    : context.dsText.bodySmall.bold.tint(colors.onSurface))
                .tabular,
          ),
        ],
      ),
    );
  }
}

class _InvoiceSkeleton extends StatelessWidget {
  const _InvoiceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.line(width: 160, height: 20),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.line(width: 200),
            SizedBox(height: DsSpacing.xl),
            DsSkeleton.box(height: 56, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.xs),
            DsSkeleton.box(height: 56, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.xl),
            DsSkeleton.line(width: 140),
          ],
        ),
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).languageCode;
  return toWesternDigits(DateFormat.yMMMd(locale).format(value));
}
