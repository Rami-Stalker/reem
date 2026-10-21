import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';
import 'package:reem/features/seller_returns/presentation/providers/seller_returns_provider.dart';
import 'package:reem/features/seller_returns/presentation/return_labels.dart';
import 'package:reem/features/seller_returns/presentation/screens/seller_returns_screen.dart';

/// One return, in full: what she is being asked, what the customer sent as
/// proof, what it would cost, and what she can do about it.
class SellerReturnDetailScreen extends ConsumerWidget {
  const SellerReturnDetailScreen({super.key, required this.returnId});

  final String returnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(sellerReturnProvider(returnId));

    return ReemScrollPage(
      onRefresh: () async => ref.invalidate(sellerReturnProvider(returnId)),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        PremiumAppBar(title: l10n.sellerReturnsTitle, showBack: true),
        switch (async) {
          AsyncError(:final error) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                // l10n-ignore: a prefix being stripped off an error string
                message: messageOf(error),
                onRetry: () => ref.invalidate(sellerReturnProvider(returnId)),
              ),
            ),
          ),
          AsyncData(:final value) => _Body(request: value),
          _ => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsLoadingIndicator(),
            ),
          ),
        },
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.request});

  final ReturnRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final acting = ref.watch(
      sellerReturnsNotifierProvider.select((s) => s.actingId == request.id),
    );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      sliver: SliverList.list(
        children: [
          // ── What is being asked ──────────────────────────────────────────
          SellerPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.returnReasonLabel(request.reason),
                        style: context.dsText.cardTitle.displayFamily.bold.tint(palette.ink),
                      ),
                    ),
                    SellerStatusPill(
                      label: context.returnStatusLabel(request.status),
                      icon: Icons.circle,
                      color: context.returnStatusColor(request.status),
                    ),
                  ],
                ),
                DsGaps.vXxxs,
                _Muted(request.number),
                if (request.reasonNote case final String note
                    when note.trim().isNotEmpty) ...[
                  const SizedBox(height: DsSpacing.sm),
                  Text(
                    note,
                    style: context.dsText.body.tint(palette.ink).copyWith(height: 1.6),
                  ),
                ],
                const SizedBox(height: DsSpacing.sm),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => context.push(
                    RoutePaths.sellerOrderDetailFor(request.parcel.sellerOrderId),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: Text(
                    l10n.returnParcelLabel(request.parcel.sellerOrderNumber),
                  ),
                ),
                if (request.windowClosesAt case final DateTime closes) ...[
                  const SizedBox(height: DsSpacing.xs),
                  _Muted(l10n.returnWindowCloses(_formatDate(closes))),
                ],
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.md),

          // ── The goods ────────────────────────────────────────────────────
          _SectionLabel(l10n.returnItems),
          SellerPanel(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < request.items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 70, color: palette.line),
                  _ItemRow(line: request.items[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.md),

          // ── Her proof ────────────────────────────────────────────────────
          _SectionLabel(l10n.returnEvidence),
          if (request.evidence.isEmpty)
            SellerPanel(child: _Muted(l10n.returnNoEvidence))
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: request.evidence.length,
                separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
                itemBuilder: (context, index) => AuthorizedMediaImage(
                  url: request.evidence[index],
                  width: DsSizes.thumbLg,
                  height: DsSizes.thumbLg,
                  borderRadius: DsRadius.borderMd,
                  variantWidth: MediaVariants.thumbnail,
                ),
              ),
            ),
          const SizedBox(height: DsSpacing.md),

          // ── The money ────────────────────────────────────────────────────
          if (request.refund case final RefundQuote refund) ...[
            _SectionLabel(
              refund.settled ? l10n.returnRefundSettled : l10n.returnRefundQuote,
            ),
            _RefundPanel(refund: refund),
            const SizedBox(height: DsSpacing.md),
          ],

          // ── What she can do ──────────────────────────────────────────────
          if (request.availableActions.isNotEmpty) ...[
            if (request.status == ReturnStatus.received)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                child: _Muted(l10n.returnRefundIsPlatforms),
              ),
            if (acting)
              const DsLoadingIndicator()
            else
              for (final action in request.availableActions)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                  child: DsButton(
                    label: context.returnActionLabel(action),
                    icon: context.returnActionIcon(action),
                    variant: action == ReturnAction.reject
                        ? DsButtonVariant.danger
                        : DsButtonVariant.primary,
                    onPressed: () =>
                        runReturnAction(context, ref, request, action),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      DateFormat('d MMMM', 'ar').format(date.toLocal());
}

class _RefundPanel extends StatelessWidget {
  const _RefundPanel({required this.refund});

  final RefundQuote refund;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    return SellerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            refund.amount.format(),
            style: context.dsText.screenTitle.bold.tint(refund.settled ? palette.ink : palette.muted),
          ),
          if (!refund.settled) _Muted(l10n.returnRefundQuoteHint),
          if (refund.goods case final goods?) ...[
            const SizedBox(height: DsSpacing.sm),
            _Line(label: l10n.returnRefundGoods, value: goods.format()),
          ],
          if (refund.returnShippingFee case final fee?)
            _Line(
              label: l10n.returnRefundShipping,
              value: fee.format(),
              // Who eats the return leg is the seller's real question here,
              // so it rides on the fee rather than sitting in its own row.
              trailing: refund.borneBy == null
                  ? null
                  : context.returnBearerLabel(refund.borneBy!),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final style = context.dsText.labelMedium.tint(palette.muted);

    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.xxs),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          if (trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpacing.sm),
              child: Text(trailing!, style: style),
            ),
          Text(
            value,
            style: style.copyWith(
              color: palette.ink,
              fontWeight: DsTypography.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line});

  final ReturnLine line;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: DsRadius.borderSm,
            child: SizedBox(
              width: 46,
              height: 46,
              child: line.image == null
                  ? ColoredBox(
                      color: palette.background,
                      child: Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: palette.muted,
                      ),
                    )
                  : AuthorizedMediaImage(
                      url: line.image!,
                      variantWidth: MediaVariants.thumbnail,
                    ),
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body.medium.tint(palette.ink),
                ),
                if (line.variant case final String variant
                    when variant.isNotEmpty)
                  _Muted(variant),
              ],
            ),
          ),
          Text(
            context.l10n.returnQuantity('${line.quantity}'),
            style: context.dsText.tileTitle.bold.tint(palette.ink),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DsSpacing.xs),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label.toUpperCase(),
        style: DsTypography.overline(context.atelier.muted),
      ),
    ),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      style: context.dsText.caption.tint(context.atelier.muted),
    ),
  );
}
