import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/market/domain/entities/market.dart';
import 'package:ohara/features/market/presentation/providers/market_providers.dart';
import 'package:ohara/features/market/presentation/widgets/market_pieces.dart';
import 'package:ohara/features/product_social/presentation/widgets/product_like_button.dart';

/// One assembled look.
///
/// Three things on the page, in this order: the pieces with a reason under
/// each, the cheaper ways to fill the same slots, and the price of the whole.
/// The alternatives sit *above* the buy button on purpose — a comparison
/// offered after the decision is made is a comparison nobody reads, and the
/// point of showing it at all is that she should be able to spend less.
class BundleScreen extends ConsumerWidget {
  const BundleScreen({super.key, required this.bundleId});

  final String bundleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final async = ref.watch(bundleProvider(bundleId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: context.l10n.marketLookTitle),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.marketLookFailed,
          onRetry: () => ref.invalidate(bundleProvider(bundleId)),
        ),
        data: (bundle) => _Body(bundle: bundle),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.bundle});

  final Bundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final alternatives = ref.watch(bundleAlternativesProvider(bundle.id));

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.lg),
      children: [
        Text(
          bundle.title,
          style: context.dsText.sectionTitle.tint(colors.onSurface),
        ),
        if (bundle.crossesShops) ...[
          DsGaps.vXs,
          ReasonLine(
            icon: Icons.storefront_outlined,
            text: context.l10n.marketLookFromShops(bundle.sellerCount),
          ),
        ],
        DsGaps.vLg,

        for (final item in bundle.items) ...[
          _PieceTile(item: item),
          DsGaps.vSm,
        ],

        DsGaps.vMd,
        alternatives.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (rows) => rows.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.marketCheaperOptions,
                      style: context.dsText.cardTitle.tint(colors.onSurface),
                    ),
                    DsGaps.vXs,
                    Text(
                      context.l10n.marketCheaperOptionsBody,
                      style: context.dsText.caption.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                    DsGaps.vSm,
                    for (final alternative in rows) ...[
                      _AlternativeTile(alternative: alternative),
                      DsGaps.vXs,
                    ],
                  ],
                ),
        ),

        DsGaps.vXl,
        DsGlassCard(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.marketLookTotal,
                      style: context.dsText.caption.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      sypText(bundle.totalSyp),
                      style: DsTypography.price(
                        colors.price,
                        size: DsTypography.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              DsButton(
                label: context.l10n.marketSeePieces,
                // `DsButton` expands to fill by default, which inside a Row is
                // an infinite width and a layout assertion at render time —
                // clean under `flutter analyze`, fatal on screen.
                isExpanded: false,
                onPressed: () =>
                    context.push(
                    RoutePaths.productDetailsOf(bundle.items.first.productId),
                  ),
              ),
            ],
          ),
        ),
        DsGaps.vXxl,
      ],
    );
  }
}

/// One piece, with the reason it is here.
///
/// The reason is not optional decoration and is never truncated away — it is
/// the difference between a bundle and a gift basket, and a piece that cannot
/// say why it is in the set has no business being in it.
class _PieceTile extends StatelessWidget {
  const _PieceTile({required this.item});

  final BundleItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return DsGlassCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      onTap: () => context.push(RoutePaths.productDetailsOf(item.productId)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MarketThumb(imageUrl: item.imageUrl, size: 64),
              // A bundle carries a *projection* of each piece — a title, a
              // price and a product id — not the product itself, which is why
              // the like is asked for by id. Being a projection is not a reason
              // to be the one place a piece cannot be liked.
              PositionedDirectional(
                top: 2,
                end: 2,
                child: ProductLikeButton.forId(
                  item.productId,
                  compact: true,
                  showCount: false,
                ),
              ),
            ],
          ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.slotLabel != null) ...[
                      DsBadge(label: item.slotLabel!),
                      DsGaps.hXs,
                    ],
                    Expanded(
                      child: Text(
                        sypText(item.priceSyp),
                        textAlign: TextAlign.end,
                        style: DsTypography.price(
                          colors.price,
                          size: DsTypography.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
                DsGaps.vXxs,
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body.tint(colors.onSurface),
                ),
                if (item.sellerName != null)
                  Text(
                    context.l10n.marketFromSeller(item.sellerName!),
                    style: context.dsText.micro.tint(colors.onSurfaceVariant),
                  ),
                if (item.reason != null && item.reason!.isNotEmpty) ...[
                  DsGaps.vXs,
                  ReasonLine(text: item.reason!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({required this.alternative});

  final BundleAlternative alternative;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return DsGlassCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      onTap: () =>
          context.push(
        RoutePaths.productDetailsOf(alternative.alternativeProductId),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (alternative.slotLabel != null) ...[
                DsBadge(label: alternative.slotLabel!),
                DsGaps.hXs,
              ],
              Expanded(
                child: Text(
                  context.l10n.marketSave(sypText(alternative.savingSyp)),
                  textAlign: TextAlign.end,
                  style: context.dsText.caption.semibold.tint(colors.successInk),
                ),
              ),
            ],
          ),
          DsGaps.vXs,
          Text(
            alternative.alternativeTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.body.tint(colors.onSurface),
          ),
          Text(
            context.l10n.marketInsteadOf(
              alternative.currentTitle,
              sypText(alternative.alternativePriceSyp),
              sypText(alternative.currentPriceSyp),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.micro.tint(colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
