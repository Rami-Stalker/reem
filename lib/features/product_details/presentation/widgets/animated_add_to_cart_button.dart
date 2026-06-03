import 'package:flutter/material.dart';

class AnimatedAddToCartButton
    extends StatefulWidget {
  const AnimatedAddToCartButton({
    super.key,
  });

  @override
  State<AnimatedAddToCartButton>
      createState() =>
          _AnimatedAddToCartButtonState();
}

class _AnimatedAddToCartButtonState
    extends State<AnimatedAddToCartButton> {
  bool added = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          added = true;
        });

        Future.delayed(
          const Duration(seconds: 2),
          () {
            if (mounted) {
              setState(() {
                added = false;
              });
            }
          },
        );
      },

      child: AnimatedContainer(
        duration:
            const Duration(
                milliseconds: 450),

        curve: Curves.easeOutExpo,

        height: 68,

        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(28),

          gradient:
              const LinearGradient(
            colors: [
              Color(0xffFF9EB5),
              Color(0xffFF5C8A),
            ],
          ),

          boxShadow: [

            BoxShadow(
              color:
                  Colors.pink.withOpacity(
                      .25),

              blurRadius: 28,
              spreadRadius: 4,
              offset:
                  const Offset(0, 14),
            ),
          ],
        ),

        child: Center(
          child: AnimatedSwitcher(
            duration:
                const Duration(
                    milliseconds: 400),

            child: added
                ? const Row(
                    key: ValueKey(1),
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                    children: [

                      Icon(
                        Icons.check,
                        color:
                            Colors.white,
                      ),

                      SizedBox(width: 12),

                      Text(
                        "Added Successfully",

                        style: TextStyle(
                          color:
                              Colors.white,

                          fontSize: 18,

                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    key: ValueKey(2),
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                    children: [

                      Icon(
                        Icons
                            .shopping_bag_rounded,

                        color:
                            Colors.white,
                      ),

                      SizedBox(width: 12),

                      Text(
                        "Add To Cart",

                        style: TextStyle(
                          color:
                              Colors.white,

                          fontSize: 18,

                          fontWeight:
                              FontWeight
                                  .bold,
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