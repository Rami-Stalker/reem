import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../discovery/presentation/widgets/product_card_compact.dart';
import '../providers/home_state.dart';

/// Renders one home product collection (loading / items / error) as a
/// horizontal rail. Empty sections collapse to nothing.
class HomeCollectionRail extends StatelessWidget {
  const HomeCollectionRail({
    super.key,
    required this.section,
    required this.title,
    this.onSeeAll,
    this.onRetry,
  });

  final HomeSection section;
  final String title;
  final VoidCallback? onSeeAll;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox.shrink();
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    fontSize: DsTypography.titleMedium,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (onSeeAll != null && section.hasItems)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: DsTypography.semiBold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: _buildBody(context),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (section.isLoading && !section.hasItems) {
      return const Center(child: CircularProgressIndicator());
    }
    if (section.hasError && !section.hasItems) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      itemCount: section.products.length,
      separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.md),
      itemBuilder: (_, i) {
        final product = section.products[i];
        return SizedBox(
          width: 150,
          child: ProductCardCompact(
            product: product,
            onTap: () =>
                context.push('${RoutePaths.productDetails}?id=${product.id}'),
          ),
        );
      },
    );
  }
}
