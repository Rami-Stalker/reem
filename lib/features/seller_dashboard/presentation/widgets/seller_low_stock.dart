import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_low_stock_item.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';

class SellerLowStockAlert extends ConsumerWidget {
  const SellerLowStockAlert({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 140, borderRadius: DsRadius.xxl)),
      );
    }

    final items = state.data?.lowStock ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    final criticalCount = items.where((i) => i.isCritical || i.isOutOfStock).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: DsRadius.borderXxl,
          border: Border.all(
            color: c.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.md, DsSpacing.md, DsSpacing.md, DsSpacing.xxxs),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DsSpacing.xs),
                    decoration: BoxDecoration(
                      color: c.warning.withValues(alpha: 0.14),
                      borderRadius: DsRadius.borderSm,
                    ),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 18, color: c.warning),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.sellerLowStockTitle,
                          style: context.dsText.tileTitle
                              .copyWith(fontWeight: DsTypography.bold),
                        ),
                        Text(
                          context.l10n.sellerRestockNeeded(criticalCount),
                          style: context.dsText.caption
                              .copyWith(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(RoutePaths.myProducts),
                    child: Text(context.l10n.sellerRestock),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.md, DsSpacing.xxxs, DsSpacing.md, DsSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: DsSpacing.sm),
                itemBuilder: (context, i) => _LowStockCard(item: items[i])
                    .animate(delay: (i * 50).ms)
                    .fadeIn(duration: 280.ms)
                    .slideX(begin: 0.06, end: 0, duration: 280.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.item});

  final SellerLowStockItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final isOut = item.isOutOfStock;
    final isCritical = item.isCritical;
    final color = isOut ? c.error : isCritical ? c.warning : c.info;

    return GestureDetector(
      onTap: () => context.push(RoutePaths.myProducts),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: DsRadius.borderMd,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(DsRadius.md)),
              child: CachedNetworkImage(
                imageUrl: MediaVariants.thumb(item.imageUrl),
                width: 56,
                height: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: MediaDecode.widthFor(context, 56),
                placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                errorWidget: (_, _, _) =>
                    ColoredBox(color: c.surfaceVariant),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.micro.semibold.tint(c.onSurface).copyWith(height: 1.2),
                    ),
                    DsGaps.vXxs,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.xs, vertical: DsSpacing.xxxs),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: DsRadius.borderFull,
                      ),
                      child: Text(
                        isOut
                            ? context.l10n.sellerOutOfStock
                            : context.l10n.sellerStockLeft(item.stock),
                        style: context.dsText.micro.bold.tint(color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
