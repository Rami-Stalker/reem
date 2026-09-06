import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';

/// The shop's departments.
///
/// Three things were wrong here. The page built its own `SliverAppBar` on a
/// flat surface, so it was the one buyer screen without the frosted gradient
/// header. Every tile carried a fabricated product count — 245 dresses, 98
/// pieces of jewellery — presented as fact. And the tap handler was an empty
/// block, so the whole grid was decoration.
///
/// The taxonomy itself is curated rather than fetched: the client has no
/// categories endpoint yet. What it can do honestly is hand the department to
/// search, which is a real, filtered result set.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = _departments(context);

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.categories, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: DsSpacing.md,
              crossAxisSpacing: DsSpacing.md,
              childAspectRatio: 0.95,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) =>
                _DepartmentCard(department: categories[index], index: index),
          ),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  List<_Department> _departments(BuildContext context) {
    final l10n = context.l10n;
    return [
      _Department(
        name: l10n.categoryDresses,
        subtitle: l10n.categoryDressesBlurb,
        icon: Icons.checkroom_rounded,
        gradient: DsGradients.primarySoft,
      ),
      _Department(
        name: l10n.categoryBeauty,
        subtitle: l10n.categoryBeautyBlurb,
        icon: Icons.face_retouching_natural,
        gradient: DsGradients.lavenderBlush,
      ),
      _Department(
        name: l10n.categoryBags,
        subtitle: l10n.categoryBagsBlurb,
        icon: Icons.shopping_bag_rounded,
        gradient: DsGradients.sunset,
      ),
      _Department(
        name: l10n.categoryJewellery,
        subtitle: l10n.categoryJewelleryBlurb,
        icon: Icons.diamond_outlined,
        gradient: DsGradients.champagne,
      ),
      _Department(
        name: l10n.categoryGifts,
        subtitle: l10n.categoryGiftsBlurb,
        icon: Icons.card_giftcard_rounded,
        gradient: DsGradients.rewards,
      ),
      _Department(
        name: l10n.categoryShoes,
        subtitle: l10n.categoryShoesBlurb,
        icon: Icons.roller_skating_rounded,
        gradient: DsGradients.accent,
      ),
      _Department(
        name: l10n.categoryAccessories,
        subtitle: l10n.categoryAccessoriesBlurb,
        icon: Icons.shopping_basket_rounded,
        gradient: DsGradients.primary,
      ),
      _Department(
        name: l10n.categoryFragrance,
        subtitle: l10n.categoryFragranceBlurb,
        icon: Icons.spa_rounded,
        gradient: DsGradients.soft,
      ),
    ];
  }
}

class _Department {
  const _Department({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department, required this.index});

  final _Department department;
  final int index;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;

    return DsStaggerAnimations.item(
      index: index,
      child: SurfaceCard(
        onTap: () => context.push('${RoutePaths.search}?q=${department.name}'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: DsSizes.avatarXl,
              height: DsSizes.avatarXl,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: department.gradient,
                boxShadow: [
                  BoxShadow(
                    color: department.gradient.colors.first.withValues(
                      alpha: 0.3,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                department.icon,
                size: DsSizes.iconLg,
                color: DsColors.onMedia,
              ),
            ),
            DsGaps.vMd,
            Text(
              department.name,
              textAlign: TextAlign.center,
              style: text.tileTitle.bold,
            ),
            DsGaps.vXxs,
            Text(
              department.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.caption,
            ),
          ],
        ),
      ),
    );
  }
}
