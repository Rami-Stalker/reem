import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import 'category_card.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    const categories = [
      (title: 'Dresses', icon: Icons.checkroom_rounded),
      (title: 'Beauty', icon: Icons.face_retouching_natural),
      (title: 'Bags', icon: Icons.shopping_bag_rounded),
      (title: 'Jewelry', icon: Icons.diamond_outlined),
      (title: 'Gifts', icon: Icons.card_giftcard_rounded),
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
            separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.md),
            itemBuilder: (context, index) {
              final c = categories[index];
              return CategoryCard(title: c.title, icon: c.icon);
            },
          ),
        ),
      ],
    );
  }
}
