import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/router/route_names.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    const categories = [
      (title: 'ملابس', icon: FontAwesomeIcons.shirt),
      (title: 'مكياج', icon: FontAwesomeIcons.wandMagicSparkles),
      (title: 'عطور', icon: FontAwesomeIcons.sprayCanSparkles),
      (title: 'حقائب', icon: FontAwesomeIcons.bagShopping),
      (title: 'ورود', icon: FontAwesomeIcons.seedling),
      (title: 'أحذية', icon: FontAwesomeIcons.shoePrints),
      (title: 'شوكولا', icon: FontAwesomeIcons.cookieBite),
      (title: 'العناية بالجسم', icon: FontAwesomeIcons.pumpSoap),
      (title: 'هدايا', icon: FontAwesomeIcons.gift),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReemSectionHeader(
          title: context.l10n.homeShopByCategory,
          subtitle: context.l10n.homeRecommendedEyebrow,
        ),
        const SizedBox(height: DsSpacing.lg),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
            itemBuilder: (context, index) {
              final c = categories[index];
              return GestureDetector(
                onTap: () => context.pushNamed(
                  RouteNames.category,
                  pathParameters: {'category': c.title.toLowerCase()},
                ),
                child: _CategoryCard(title: c.title, icon: c.icon),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.title, required this.icon});

  final String title;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      width: 100,
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxl,
        color: colors.surface.withValues(alpha: 0.9),
        border: Border.all(color: colors.glassBorder),
        boxShadow: context.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.primaryGradient,
            ),
            child: Center(
              child: FaIcon(icon, color: colors.onPrimary, size: 26),
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontWeight: DsTypography.semiBold,
              fontSize: DsTypography.labelLarge,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
