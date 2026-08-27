import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// `intl` exports a TextDirection of its own; the one meant here is the
// framework's, used to pin document numbers left-to-right.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../domain/entities/invoice.dart';
import '../providers/invoices_provider.dart';

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

    return ReemScrollPage(
      onRefresh: () async => ref.invalidate(orderInvoicesProvider(orderId)),
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.invoices),
        ),
        async.when(
          loading: () => const SliverToBoxAdapter(child: _Skeleton()),
          // An order that has not shipped yet cannot be invoiced (Q39). That
          // is the ordinary case, not a failure, so it reads as an explanation
          // rather than an error with a retry button.
          error: (_, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsEmptyState(
                icon: Icons.receipt_long_outlined,
                title: l10n.invoiceEmptyTitle,
                message: l10n.invoiceEmptyBody,
              ),
            ),
          ),
          data: (rows) => rows.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DsSpacing.xxl,
                    ),
                    child: DsEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.invoiceEmptyTitle,
                      message: l10n.invoiceEmptyBody,
                    ),
                  ),
                )
              : SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DsSpacing.xs),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.lg,
                    ),
                    child: _InvoiceRow(summary: rows[index]),
                  ),
                ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
                    style: TextStyle(
                      fontSize: DsTypography.bodyMedium,
                      fontWeight: DsTypography.semiBold,
                      color: colors.onSurface,
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      summary.number,
                      style: TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: DsTypography.labelSmall,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    toWesternDigits(
                      DateFormat.yMMMd(locale).format(summary.issuedAt),
                    ),
                    style: TextStyle(
                      fontSize: DsTypography.labelSmall,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              summary.grandTotal.format(),
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.bodyMedium,
                fontWeight: DsTypography.bold,
                color: colors.price,
              ),
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
