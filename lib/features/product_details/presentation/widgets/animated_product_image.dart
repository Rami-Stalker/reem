import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedProductImage
    extends StatelessWidget {
  final String image;

  const AnimatedProductImage({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: image,

      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(34),

        child: Stack(
          fit: StackFit.expand,

          children: [

            Image.network(
              image,
              fit: BoxFit.cover,
            ),

            /// OVERLAY
            Container(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,

                  end:
                      Alignment
                          .bottomCenter,

                  colors: [

                    Colors.transparent,

                    Colors.black
                        .withOpacity(.25),
                  ],
                ),
              ),
            ),

            /// LIVE TAG
            Positioned(
              top: 18,
              left: 18,

              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),

                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(24),

                  color: Colors.red,
                ),

                child: const Row(
                  children: [

                    Icon(
                      Icons.circle,
                      color:
                          Colors.white,
                      size: 10,
                    ),

                    SizedBox(width: 8),

                    Text(
                      "LIVE",

                      style: TextStyle(
                        color:
                            Colors.white,

                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 700.ms)
        .scale(
          begin:
              const Offset(.92, .92),

          curve: Curves.easeOutExpo,
        );
  }
}