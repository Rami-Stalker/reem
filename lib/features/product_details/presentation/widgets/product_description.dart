import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProductDescription
    extends StatefulWidget {
  const ProductDescription({
    super.key,
  });

  @override
  State<ProductDescription>
      createState() =>
          _ProductDescriptionState();
}

class _ProductDescriptionState
    extends State<ProductDescription> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(26),

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
                .withOpacity(.72),

            Colors.white
                .withOpacity(.35),
          ],
        ),

        border: Border.all(
          color:
              Colors.white.withOpacity(.5),
        ),

        boxShadow: [

          BoxShadow(
            color:
                Colors.pink.withOpacity(.06),

            blurRadius: 28,
            spreadRadius: 3,
            offset:
                const Offset(0, 16),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          /// TITLE
          const Text(
            'Description',

            style: TextStyle(
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          /// DESCRIPTION
          AnimatedCrossFade(
            duration:
                const Duration(
                    milliseconds: 450),

            crossFadeState: expanded
                ? CrossFadeState
                    .showSecond
                : CrossFadeState
                    .showFirst,

            firstChild: Text(
              'Elegant premium fashion crafted with luxurious materials and a timeless feminine silhouette. Designed to deliver beauty, confidence, and sophistication in every detail.',

              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,

              style: TextStyle(
                color: Colors.grey[700],
                height: 1.8,
                fontSize: 16,
              ),
            ),

            secondChild: Text(
              'Elegant premium fashion crafted with luxurious materials and a timeless feminine silhouette. Designed to deliver beauty, confidence, and sophistication in every detail.\n\nThis collection combines modern luxury with soft feminine aesthetics, offering unmatched comfort and premium craftsmanship. Perfect for luxury lifestyle lovers seeking elegance, exclusivity, and high-end fashion experiences.',

              style: TextStyle(
                color: Colors.grey[700],
                height: 1.8,
                fontSize: 16,
              ),
            ),
          ),

          const SizedBox(height: 24),

          /// BUTTON
          GestureDetector(
            onTap: () {
              setState(() {
                expanded = !expanded;
              });
            },

            child: Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                Text(
                  expanded
                      ? 'Show Less'
                      : 'Read More',

                  style: const TextStyle(
                    color:
                        Color(0xffFF5C8A),

                    fontWeight:
                        FontWeight.bold,

                    fontSize: 16,
                  ),
                ),

                const SizedBox(width: 10),

                AnimatedRotation(
                  turns:
                      expanded ? .5 : 0,

                  duration:
                      const Duration(
                          milliseconds:
                              350),

                  child: const Icon(
                    Icons
                        .keyboard_arrow_down_rounded,

                    color:
                        Color(0xffFF5C8A),
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