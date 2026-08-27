import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProductPriceSection
    extends StatelessWidget {
  const ProductPriceSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(24),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(32),

        gradient:
            LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,

          colors: [

            Colors.white
                .withOpacity(.75),

            Colors.white
                .withOpacity(.35),
          ],
        ),

        border: Border.all(
          color:
              Colors.white.withOpacity(.6),
        ),

        boxShadow: [

          BoxShadow(
            color:
                Colors.pink.withOpacity(.08),

            blurRadius: 35,
            spreadRadius: 4,
            offset:
                const Offset(0, 18),
          ),
        ],
      ),

      child: Row(
        children: [

          /// PRICE
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                Text(
                  'Price',

                  style: TextStyle(
                    color:
                        Colors.grey[600],

                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [

                    const Text(
                      '\$240',

                      style: TextStyle(
                        fontSize: 34,
                        fontWeight:
                            FontWeight
                                .bold,

                        color:
                            Color(0xffFF5C8A),
                      ),
                    ),

                    const SizedBox(
                        width: 14),

                    Text(
                      '\$420',

                      style: TextStyle(
                        decoration:
                            TextDecoration
                                .lineThrough,

                        color:
                            Colors.grey[500],

                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// SALE BADGE
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),

            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                      24),

              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xffFF9EB5),
                  Color(0xffFF5C8A),
                ],
              ),
            ),

            child: const Column(
              children: [

                Text(
                  '45%',

                  style: TextStyle(
                    color: Colors.white,

                    fontSize: 22,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'OFF',

                  style: TextStyle(
                    color:
                        Colors.white70,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 700.ms)
        .slideY(begin: .15);
  }
}