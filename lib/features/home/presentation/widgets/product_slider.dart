import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../../../../core/shared/wedgets/cards/animated_product_card.dart';

class ProductSlider extends StatelessWidget {
  const ProductSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReemSectionHeader(
          title: 'New Arrivals',
          subtitle: 'Fresh picks for you',
        ),
        const SizedBox(height: DsSpacing.lg),
        SizedBox(
          height: 340,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.lg),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 250,
                child: AnimatedProductCard(
                  image:
                      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=500&sig=$index',
                  title: 'Silk Collection',
                  price: '\$${(index + 1) * 89}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
