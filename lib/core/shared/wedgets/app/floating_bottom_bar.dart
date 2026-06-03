import 'dart:ui';

import 'package:flutter/material.dart';

class FloatingBottomBar
    extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<FloatingBottomBar>
      createState() =>
          _FloatingBottomBarState();
}

class _FloatingBottomBarState
    extends State<FloatingBottomBar> {
  final items = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.favorite_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.all(20),

      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(30),

        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),

          child: Container(
            height: 74,

            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(
                      .12),

              borderRadius:
                  BorderRadius.circular(
                      30),

              border: Border.all(
                color: Colors.white
                    .withOpacity(.18),
              ),
            ),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceAround,

              children: List.generate(
                items.length,
                (index) {
                  final selected =
                      widget.currentIndex ==
                          index;

                  return GestureDetector(
                    onTap: () =>
                        widget.onTap(index),

                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                              milliseconds:
                                  350),

                      padding:
                          const EdgeInsets
                              .all(14),

                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,

                        gradient: selected
                            ? const LinearGradient(
                                colors: [
                                  Color(
                                      0xffFF9EB5),
                                  Color(
                                      0xffFF5C8A),
                                ],
                              )
                            : null,
                      ),

                      child: Icon(
                        items[index],

                        color: selected
                            ? Colors.white
                            : Colors.black54,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}