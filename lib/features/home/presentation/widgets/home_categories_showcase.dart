import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/domain/entities/home_category.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';

/// "Shop by category" — a rail of landscape merchandising tiles.
///
/// These used to be circular medallions, which read as *stories*: the same
/// shape, the same size, the same ring, sitting two sections above the actual
/// stories rail. A department is not a person and has nothing to watch, so the
/// shape now says shelf instead — a wide framed plate with the department name
/// and its piece count set over the photo. Featured departments keep a
/// champagne hairline as the only carry-over.
class HomeCategoriesShowcase extends ConsumerWidget {
  const HomeCategoriesShowcase({super.key});

  static const double _width = 138;
  static const double _height = 92;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final categories = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.featuredCategories ?? const <HomeCategory>[],
      ),
    );

    if (!isLoading && categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          eyebrow: context.l10n.homeCategoriesEyebrow,
          title: context.l10n.homeShopByCategory,
          onSeeAll: () => context.push(RoutePaths.categories),
        ),
        SizedBox(
          height: _height,
          child: isLoading
              ? _skeleton()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: DsSpacing.sm),
                  itemBuilder: (context, i) => _CategoryTile(
                    category: categories[i],
                    onTap: () => context.push(
                      '/category/${Uri.encodeComponent(categories[i].label)}',
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
        itemBuilder: (_, _) => const DsSkeleton.box(
          width: _width,
          height: _height,
          borderRadius: DsRadius.xl,
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final HomeCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    final tile = Container(
      width: HomeCategoriesShowcase._width,
      height: HomeCategoriesShowcase._height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(DsRadius.xl),
        boxShadow: context.shadowSoft,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: category.imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: DsMotion.normal,
            placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
            errorWidget: (_, _, _) => ColoredBox(color: c.surfaceVariant),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: context.imageScrim),
            ),
          ),
          if (category.isFeatured)
            PositionedDirectional(
              top: DsSpacing.xs,
              end: DsSpacing.xs,
              child: DsSparkle(size: 11, color: c.accent),
            ),
          PositionedDirectional(
            start: DsSpacing.sm,
            end: DsSpacing.xs,
            bottom: DsSpacing.xs + 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: DsTypography.bold,
                    height: 1.2,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
                if (category.productCount > 0)
                  Text(
                    context.l10n.piecesCount(_compact(category.productCount)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return DsScaleAnimations.tapScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: category.isFeatured
          ? DsGradientBorder(
              radius: DsRadius.xl + 1.4,
              width: 1.4,
              gradient: context.champagneGradient,
              backgroundColor: c.surfaceVariant,
              child: tile,
            )
          : tile,
    );
  }

  static String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
