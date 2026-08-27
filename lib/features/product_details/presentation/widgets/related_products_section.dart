import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/cards/animated_product_card.dart';


class RelatedProductsSection
    extends StatelessWidget {
  const RelatedProductsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          'Related Products',

          style: TextStyle(
            fontSize: 28,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 360,

          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,

            itemCount: 6,

            separatorBuilder:
                (_, __) =>
                    const SizedBox(
                      width: 22,
                    ),

            itemBuilder:
                (context, index) {
              return SizedBox(
                width: 250,

                child:
                    AnimatedProductCard(
                  image:
                      'https://images.unsplash.com/photo-1496747611176-843222e1e57c',

                  title:
                      'Luxury Collection',

                  price:
                      '\$${(index + 1) * 180}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}