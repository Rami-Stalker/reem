import 'package:flutter/material.dart';

import 'review_card.dart';

class ProductReviewsSection
    extends StatelessWidget {
  const ProductReviewsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        /// HEADER
        Row(
          children: [

            const Text(
              "Reviews",

              style: TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const Spacer(),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),

              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                        22),

                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xffFF9EB5),
                    Color(0xffFF5C8A),
                  ],
                ),
              ),

              child: const Row(
                children: [

                  Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 18,
                  ),

                  SizedBox(width: 8),

                  Text(
                    "4.9",

                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        /// LIST
        ListView.separated(
          shrinkWrap: true,

          physics:
              const NeverScrollableScrollPhysics(),

          itemCount: 3,

          separatorBuilder:
              (_, __) =>
                  const SizedBox(
                    height: 18,
                  ),

          itemBuilder:
              (context, index) {
            return ReviewCard(
              image:
                  "https://images.unsplash.com/photo-1494790108377-be9c29b29330",

              name:
                  "Sophia Luxury",

              rating: 5,

              review:
                  "Absolutely stunning quality. The fabric feels premium and elegant. One of the best luxury fashion purchases I’ve ever made.",
            );
          },
        ),
      ],
    );
  }
}