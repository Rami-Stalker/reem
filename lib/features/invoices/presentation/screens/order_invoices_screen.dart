import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// `intl` exports a TextDirection of its own; the one meant here is the
// framework's, used to pin document numbers left-to-right.
import 'package:intl/intl.dart' hide TextDirection;

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/utils/arabic_numerals.dart';
import 'package:ohara/features/invoices/domain/entities/invoice.dart';
import 'package:ohara/features/invoices/presentation/providers/invoices_provider.dart';

/// Q51 — every document raised against one order: hers, and each seller's.
///
/// Opening this screen is what issues her invoice. That is deliberate: a
/// document nobody has asked for does not need to exist, and issuing one the
/// moment an order is placed would burn a number on a basket she may still
/// change (Q39). Asking for the invoices *is* the request.
class OrderInvoicesScreen extends ConsumerWidget {
  const OrderInvoicesScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(orderInvoicesProvider(orderId));

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(orderInvoicesProvider(orderId)),
      slivers: [
        PremiumAppBar(title: l10n.invoices, showBack: true),
        async.when(
          loading: () => const SliverToBoxAdapter(child: _Skeleton()),
          // A failure is a failure now. It used to render the same «لا فواتير
          // بعد» as an order that is simply too early to invoice, so a request
          // that never reached the server looked like a rule about shipping —
          // and the screen offered nothing to try again with.
          error: (error, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                message: error is Failure ? error.displayMessage : null,
                onRetry: () => ref.invalidate(orderInvoicesProvider(orderId)),
              ),
            ),
          ),
          data: (view) => switch (view) {
            // Q39/Q51 — an order she can still change has nothing to invoice.
            InvoicesNotYet() => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsEmptyState(
                  icon: Icons.schedule_rounded,
                  title: l10n.invoiceEmptyTitle,
                  message: l10n.invoiceEmptyBody,
                ),
              ),
            ),
            InvoicesIssued(:final rows) when rows.isEmpty => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.invoiceEmptyTitle,
                  message: l10n.invoiceEmptyBody,
                ),
              ),
            ),
            InvoicesIssued(:final rows) => SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xs),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                child: _InvoiceRow(summary: rows[index]),
              ),
            ),
          },
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.summary});

  final InvoiceSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    return InkWell(
      borderRadius: BorderRadius.circular(DsRadius.lg),
      onTap: () => context.push(RoutePaths.invoiceOf(summary.id)),
      child: Container(
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
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                summary.kind == InvoiceKind.sellerOrder
                    ? Icons.storefront_outlined
                    : Icons.receipt_long_rounded,
                size: 18,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.kind == InvoiceKind.sellerOrder
                        ? l10n.invoiceSellerCopy
                        : l10n.invoiceCustomerCopy,
                    style: context.dsText.body.semibold.tint(colors.onSurface),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      summary.number,
                      style: context.dsText.caption.tint(colors.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    toWesternDigits(
                      DateFormat.yMMMd(locale).format(summary.issuedAt),
                    ),
                    style: context.dsText.caption.tint(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              summary.grandTotal.format(),
              style: context.dsText.body.bold.tint(colors.price),
            ),
            const SizedBox(width: DsSpacing.xxs),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            DsSkeleton.box(height: 72, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.xs),
            DsSkeleton.box(height: 72, borderRadius: DsRadius.lg),
          ],
        ),
      ),
    );
  }
}
