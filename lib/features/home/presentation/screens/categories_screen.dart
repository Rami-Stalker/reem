import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});  

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    
    final categories = _getCategories();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: colors.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
              title: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => context.primaryGradient.createShader(bounds),
                child: Text(
                  context.l10n.categories,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    fontSize: DsTypography.titleLarge,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.onSurface),
              onPressed: () => context.pop(),
            ),
          ),

          // Categories Grid
          SliverPadding(
            padding: const EdgeInsets.all(DsSpacing.lg),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: DsSpacing.md,
                crossAxisSpacing: DsSpacing.md,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = categories[index];
                  return _CategoryCard(
                    category: category,
                    index: index,
                  );
                },
                childCount: categories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Category> _getCategories() {
    return [
      _Category(
        name: 'فساتين',
        subtitle: 'سهرة وكاجوال',
        icon: Icons.checkroom_rounded,
        gradient: DsGradients.primarySoft,
        count: 245,
      ),
      _Category(
        name: 'مكياج',
        subtitle: 'تجميل وعناية بالبشرة',
        icon: Icons.face_retouching_natural,
        gradient: DsGradients.lavenderBlush,
        count: 189,
      ),
      _Category(
        name: 'حقائب',
        subtitle: 'حقائب يد ومحافظ',
        icon: Icons.shopping_bag_rounded,
        gradient: DsGradients.sunset,
        count: 156,
      ),
      _Category(
        name: 'مجوهرات',
        subtitle: 'عقود وأقراط',
        icon: Icons.diamond_outlined,
        gradient: DsGradients.champagne,
        count: 98,
      ),
      _Category(
        name: 'هدايا',
        subtitle: 'لحظات خاصة',
        icon: Icons.card_giftcard_rounded,
        gradient: DsGradients.rewards,
        count: 134,
      ),
      _Category(
        name: 'أحذية',
        subtitle: 'كعب عالٍ ومسطّح',
        icon: Icons.checkroom_rounded,
        gradient: DsGradients.accent,
        count: 178,
      ),
      _Category(
        name: 'إكسسوارات',
        subtitle: 'أوشحة وأكثر',
        icon: Icons.shopping_basket_rounded,
        gradient: DsGradients.primary,
        count: 112,
      ),
      _Category(
        name: 'عطور',
        subtitle: 'روائح فاخرة',
        icon: Icons.spa_rounded,
        gradient: DsGradients.soft,
        count: 67,
      ),
    ];
  }
}

class _Category {
  final String name;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final int count;

  _Category({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.count,
  });
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
  });

  final _Category category;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return GestureDetector(
      onTap: () {
        // Navigate to category products
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: DsRadius.borderXxl,
          boxShadow: context.softShadow,
          border: Border.all(color: colors.glassBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: category.gradient,
                boxShadow: [
                  BoxShadow(
                    color: category.gradient.colors.first.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                category.icon,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: DsSpacing.md),
            // Category name
            Text(
              category.name,
              style: TextStyle(
                fontSize: DsTypography.titleSmall,
                fontWeight: DsTypography.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            // Product count
            Text(
              context.l10n.piecesCount('${category.count}'),
              style: TextStyle(
                fontSize: DsTypography.labelSmall,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(
        delay: (100 * index).ms,
        duration: 400.ms,
      ).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }
}