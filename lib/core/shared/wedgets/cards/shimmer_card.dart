import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerCard extends StatelessWidget {
  final double height;
  final double borderRadius;
  final EdgeInsets padding;

  const ShimmerCard({
    super.key,
    this.height = 240,
    this.borderRadius = 32,
    this.padding =
        const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
              borderRadius),

      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
        ),

        child: Container(
          height: height,
          padding: padding,

          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
                    borderRadius),

            gradient:
                LinearGradient(
              begin: Alignment.topLeft,
              end:
                  Alignment.bottomRight,

              colors: [
                Colors.white
                    .withOpacity(.20),

                Colors.white
                    .withOpacity(.08),
              ],
            ),

            border: Border.all(
              color: Colors.white
                  .withOpacity(.18),
            ),

            boxShadow: [

              BoxShadow(
                color: Colors.pink
                    .withOpacity(.08),

                blurRadius: 30,
                spreadRadius: 3,
                offset:
                    const Offset(0, 18),
              ),
            ],
          ),

          child: Shimmer.fromColors(
            baseColor:
                Colors.white.withOpacity(.12),

            highlightColor:
                Colors.white.withOpacity(.30),

            period:
                const Duration(
                    milliseconds: 1800),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                /// IMAGE PLACEHOLDER
                Container(
                  height: 120,

                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                                24),

                    color:
                        Colors.white,
                  ),
                ),

                const SizedBox(height: 22),

                /// TITLE
                Container(
                  width: 180,
                  height: 18,

                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                                12),

                    color:
                        Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                /// SUBTITLE
                Container(
                  width: 120,
                  height: 14,

                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                                12),

                    color:
                        Colors.white,
                  ),
                ),

                const Spacer(),

                /// BUTTON
                Align(
                  alignment:
                      Alignment.bottomRight,

                  child: Container(
                    width: 90,
                    height: 38,

                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius
                              .circular(
                                  30),

                      color:
                          Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}