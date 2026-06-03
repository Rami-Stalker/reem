import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LuxuryPostCard
    extends StatefulWidget {
  final int index;

  const LuxuryPostCard({
    super.key,
    required this.index,
  });

  @override
  State<LuxuryPostCard> createState() =>
      _LuxuryPostCardState();
}

class _LuxuryPostCardState
    extends State<LuxuryPostCard> {
  bool liked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},

      child: Hero(
        tag: "post_${widget.index}",

        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(32),

          child: Stack(
            fit: StackFit.expand,

            children: [

              /// IMAGE
              Image.network(
                "https://picsum.photos/600?random=${widget.index}",
                fit: BoxFit.cover,
              ),

              /// OVERLAY
              Container(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment
                            .topCenter,
                    end:
                        Alignment
                            .bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black
                          .withOpacity(
                              .5),
                    ],
                  ),
                ),
              ),

              /// TOP ACTIONS
              Positioned(
                top: 16,
                right: 16,

                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      liked = !liked;
                    });
                  },

                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 300,
                    ),

                    width: 42,
                    height: 42,

                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      color: liked
                          ? Colors.pink
                          : Colors.white
                              .withOpacity(
                                  .15),
                    ),

                    child: Icon(
                      liked
                          ? Icons.favorite
                          : Icons
                              .favorite_border,

                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              /// BOTTOM GLASS
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,

                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                          22),

                  child: BackdropFilter(
                    filter:
                        ImageFilter.blur(
                      sigmaX: 12,
                      sigmaY: 12,
                    ),

                    child: Container(
                      padding:
                          const EdgeInsets
                              .all(16),

                      decoration:
                          BoxDecoration(
                        color: Colors
                            .white
                            .withOpacity(
                                .15),

                        borderRadius:
                            BorderRadius
                                .circular(
                                    22),

                        border: Border.all(
                          color: Colors
                              .white
                              .withOpacity(
                                  .2),
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        mainAxisSize:
                            MainAxisSize.min,

                        children: [

                          const Text(
                            "Luxury Collection",

                            style:
                                TextStyle(
                              color: Colors
                                  .white,

                              fontWeight:
                                  FontWeight
                                      .bold,

                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(
                              height: 8),

                          Row(
                            children: const [

                              Icon(
                                Icons.favorite,
                                color: Colors
                                    .white,
                                size: 18,
                              ),

                              SizedBox(
                                  width: 6),

                              Text(
                                "1.2K",

                                style:
                                    TextStyle(
                                  color: Colors
                                      .white,
                                ),
                              ),

                              Spacer(),

                              Icon(
                                Icons
                                    .shopping_bag_outlined,

                                color: Colors
                                    .white,
                                size: 18,
                              ),

                              SizedBox(
                                  width: 6),

                              Text(
                                "Shop",

                                style:
                                    TextStyle(
                                  color: Colors
                                      .white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(
            milliseconds:
                100 * widget.index,
          ),
          duration: 700.ms,
        )
        .slideY(begin: .2)
        .scale(
          begin: const Offset(
            .92,
            .92,
          ),
        );
  }
}