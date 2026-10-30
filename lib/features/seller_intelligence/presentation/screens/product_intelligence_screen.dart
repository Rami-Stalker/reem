import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_intelligence/domain/entities/intelligence.dart';
import 'package:ohara/features/seller_intelligence/presentation/providers/intelligence_providers.dart';
import 'package:ohara/features/seller_intelligence/presentation/widgets/intelligence_pieces.dart';

/// ذكاء المنتجات — her listings as a work queue.
///
/// Ordered worst first, deliberately. This is not a leaderboard and there is
/// nothing to celebrate at the top of it: a seller opens this page to find the
/// shortest path to more sales, and that is always the listing with the most
/// recoverable points. Sorting it best-first would be flattering and useless.
///
/// Each row leads with the single most valuable thing to change, because a row
/// that listed four suggestions would be a row nobody finishes reading.
class ProductIntelligenceScreen extends ConsumerWidget {
  const ProductIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final async = ref.watch(productIntelligenceProvider);

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(productIntelligenceProvider),
      background: const SellerAtelierBackground(),
      backgroundColor: palette.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.auto_awesome_rounded,
          title: context.l10n.siProductIntelligence,
        ),
        // Air between the banner and the page.
        DsGaps.sliverMd,
        ...async.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            ),
          ],
          error: (_, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsErrorState(
                  message: context.l10n.siProductsFailed,
                  onRetry: () => ref.invalidate(productIntelligenceProvider),
                ),
              ),
            ),
          ],
          data: (list) => _body(context, list),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xxl)),
      ],
    );
  }

  List<Widget> _body(BuildContext context, ProductHealthList list) {
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(DsSpacing.lg),
            child: DsEmptyState(
              icon: Icons.inventory_2_outlined,
              title: context.l10n.siNoProducts,
              message: context.l10n.siNoProductsBody,
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(child: _Summary(list: list)),
      SliverList.builder(
        itemCount: list.rows.length,
        itemBuilder: (context, i) => _ProductCard(product: list.rows[i]),
      ),
    ];
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.list});

  final ProductHealthList list;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final urgent = list.urgent.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.xs,
      ),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Row(
          children: [
            IntelligenceDial(
              score: list.averageScore,
              size: 78,
              label: context.l10n.siAverage,
            ),
            const SizedBox(width: DsSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.siProductCount(list.rows.length),
                    style: context.dsText.sectionTitle.tint(palette.ink),
                  ),
                  DsGaps.vXxs,
                  Text(
                    urgent == 0
                        ? context.l10n.siNothingUrgent
                        : context.l10n.siUrgentCount(urgent),
                    style: context.dsText.caption.tint(
                      urgent == 0 ? palette.muted : palette.critical,
                    ),
                  ),
                  DsGaps.vXxxs,
                  Text(
                    context.l10n.siWindowDays(list.windowDays),
                    style: context.dsText.micro.tint(palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerStatefulWidget {
  const _ProductCard({required this.product});

  final ProductHealth product;

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final product = widget.product;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xs,
      ),
      child: SellerPanel(
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntelligenceDial(
                  score: product.score,
                  confidence: product.confidence,
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.semibold.tint(palette.ink),
                      ),
                      DsGaps.vXxxs,
                      Row(
                        children: [
                          Text(
                            context.l10n.siViewsOrders(
                              product.views,
                              product.orders,
                            ),
                            style: context.dsText.micro.tint(palette.muted),
                          ),
                          if (!product.inStock) ...[
                            const SizedBox(width: DsSpacing.xs),
                            Text(
                              context.l10n.siSoldOut,
                              style: context.dsText.micro.tint(
                                palette.criticalInk,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: palette.muted,
                ),
              ],
            ),

            if (product.topAdvice != null) ...[
              const SizedBox(height: DsSpacing.xs),
              AdviceTile(advice: product.topAdvice!, dense: true),
              if (!_open && product.adviceCount > 1)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: DsSpacing.md,
                  ),
                  child: Text(
                    context.l10n.siMoreAdvice(product.adviceCount - 1),
                    style: context.dsText.micro.tint(palette.primary),
                  ),
                ),
            ],

            if (_open) _Detail(productId: product.productId),
          ],
        ),
      ),
    );
  }
}

/// The axes and the rest of the advice, fetched only when she opens the row.
///
/// Lazily, because the detail endpoint runs a percentile over the category and
/// there is no reason to pay that for forty rows she has not looked at.
class _Detail extends ConsumerWidget {
  const _Detail({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final async = ref.watch(productHealthProvider(productId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: DsSpacing.md),
        child: Center(child: DsLoadingIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(top: DsSpacing.sm),
        child: Text(
          context.l10n.siDetailsFailed,
          style: context.dsText.caption.tint(palette.muted),
        ),
      ),
      data: (detail) => Padding(
        padding: const EdgeInsets.only(top: DsSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: palette.line, height: DsSpacing.lg),

            for (final axis in detail.axes)
              MeasureBar(
                label: axis.label,
                score: axis.score,
                weight: axis.counted ? axis.weight : null,
                provisional: !axis.counted,
                // The three states are different and the wording says which:
                // nothing has been shown yet, versus not enough of it to be
                // sure, versus measured properly.
                unmeasuredNote: axis.evidence == 'unmeasurable'
                    ? context.l10n.siNoDataYet
                    : context.l10n.siTooFewYet,
              ),

            if (detail.peers != null) ...[
              const SizedBox(height: DsSpacing.sm),
              _Peers(peers: detail.peers!),
            ],

            if (detail.advice.length > 1) ...[
              Divider(color: palette.line, height: DsSpacing.lg),
              for (final advice in detail.advice.skip(1))
                AdviceTile(advice: advice, dense: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _Peers extends StatelessWidget {
  const _Peers({required this.peers});

  final PeerPosition peers;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final premium = peers.pricePremiumPercent;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: DsRadius.borderMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.siComparedWith(peers.peers),
            style: context.dsText.caption.semibold.tint(palette.ink),
          ),
          DsGaps.vXxs,
          if (premium != null)
            Text(
              premium.abs() < 5
                  ? context.l10n.siPriceNearMarket
                  : premium > 0
                  ? context.l10n.siPriceAbove(premium.round())
                  : context.l10n.siPriceBelow(premium.abs().round()),
              style: context.dsText.caption.tint(palette.muted),
            ),
          Text(
            context.l10n.siConversion(
              (peers.conversion * 100).toStringAsFixed(1),
              (peers.medianConversion * 100).toStringAsFixed(1),
            ),
            style: context.dsText.caption.tint(palette.muted),
          ),
        ],
      ),
    );
  }
}
