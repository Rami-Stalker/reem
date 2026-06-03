import 'package:flutter/material.dart';

import 'animated_product_image.dart';

class ProductImageSlider
    extends StatefulWidget {
  const ProductImageSlider({
    super.key,
  });

  @override
  State<ProductImageSlider>
      createState() =>
          _ProductImageSliderState();
}

class _ProductImageSliderState
    extends State<ProductImageSlider> {
  final controller =
      PageController(viewportFraction: .88);

  int current = 0;

  final images = [

    "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f",

    "https://images.unsplash.com/photo-1496747611176-843222e1e57c",

    "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        SizedBox(
          height: 420,

          child: PageView.builder(
            controller: controller,

            physics:
                const BouncingScrollPhysics(),

            onPageChanged: (index) {
              setState(() {
                current = index;
              });
            },

            itemCount: images.length,

            itemBuilder:
                (context, index) {
              return AnimatedPadding(
                duration:
                    const Duration(
                        milliseconds:
                            350),

                padding:
                    EdgeInsets.only(
                  right:
                      current == index
                          ? 0
                          : 18,

                  top:
                      current == index
                          ? 0
                          : 18,

                  bottom:
                      current == index
                          ? 0
                          : 18,
                ),

                child:
                    AnimatedProductImage(
                  image:
                      images[index],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 22),

        /// INDICATORS
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: List.generate(
            images.length,
            (index) {
              final active =
                  current == index;

              return AnimatedContainer(
                duration:
                    const Duration(
                        milliseconds:
                            300),

                margin:
                    const EdgeInsets
                        .only(
                  right: 8,
                ),

                width:
                    active ? 28 : 10,

                height: 10,

                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(30),

                  gradient: active
                      ? const LinearGradient(
                          colors: [
                            Color(
                                0xffFF9EB5),
                            Color(
                                0xffFF5C8A),
                          ],
                        )
                      : null,

                  color: active
                      ? null
                      : Colors.grey
                          .shade300,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}