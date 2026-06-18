import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/home_category.dart';
import '../providers/home_content_provider.dart';
import 'home_section_header.dart';

/// "Shop by category" — a horizontal rail of circular image medallions.
/// Featured categories wear a champagne-gold ring.
class HomeCategoriesShowcase extends ConsumerWidget {
  const HomeCategoriesShowcase({super.key});

  static const double _size = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final categories = ref.watch(
      homeContentNotifierProvider
          .select((s) => s.content?.featuredCategories ?? const <HomeCategory>[]),
    );

    if (!isLoading && categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          eyebrow: 'Browse',
          title: 'Shop by category',
          onSeeAll: () => context.push(RoutePaths.categories),
        ),
        SizedBox(
          height: _size + 38,
          child: isLoading
              ? _skeleton(context)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
                  itemBuilder: (context, i) => _CategoryMedallion(
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

  Widget _skeleton(BuildContext context) {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (_, _) => Column(
          children: [
            const DsSkeleton.circle(size: _size),
            const SizedBox(height: DsSpacing.xs),
            DsSkeleton.line(width: 44),
          ],
        ),
      ),
    );
  }
}

class _CategoryMedallion extends StatelessWidget {
  const _CategoryMedallion({required this.category, required this.onTap});

  final HomeCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    const size = HomeCategoriesShowcase._size;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: category.isFeatured ? DsGradients.champagne : null,
                color: category.isFeatured ? null : c.border,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: category.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                    errorWidget: (_, _, _) =>
                        Icon(Icons.image_outlined, color: c.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.labelMedium,
                fontWeight: DsTypography.semiBold,
                color: c.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
