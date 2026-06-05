import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/router/route_names.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    const categories = [
      (title: 'Clothing', icon: FontAwesomeIcons.shirt),
      (title: 'Makeup', icon: FontAwesomeIcons.wandMagicSparkles),
      (title: 'Perfumes', icon: FontAwesomeIcons.sprayCanSparkles),
      (title: 'Bags', icon: FontAwesomeIcons.bagShopping),
      (title: 'Flowers', icon: FontAwesomeIcons.seedling),
      (title: 'Shoes', icon: FontAwesomeIcons.shoePrints),
      (title: 'Chocolate', icon: FontAwesomeIcons.cookieBite),
      (title: 'Bath & Body', icon: FontAwesomeIcons.pumpSoap),
      (title: 'Gifts', icon: FontAwesomeIcons.gift),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReemSectionHeader(
          title: 'Shop by Category',
          subtitle: 'Curated for you',
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
