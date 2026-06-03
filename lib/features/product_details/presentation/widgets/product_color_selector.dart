import 'package:flutter/material.dart';

class ProductColorSelector
    extends StatefulWidget {
  const ProductColorSelector({
    super.key,
  });

  @override
  State<ProductColorSelector>
      createState() =>
          _ProductColorSelectorState();
}

class _ProductColorSelectorState
    extends State<ProductColorSelector> {
  int selected = 0;

  final colors = [

    const Color(0xffFF5C8A),

    Colors.black,

    Colors.purple,

    Colors.orange,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          "Select Color",

          style: TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: List.generate(
            colors.length,
            (index) {
              final active =
                  selected == index;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selected = index;
                  });
                },

                child:
                    AnimatedContainer(
                  duration:
                      const Duration(
                          milliseconds:
                              300),

                  margin:
                      const EdgeInsets
                          .only(
                    right: 16,
                  ),

                  width: active
                      ? 62
                      : 52,

                  height: active
                      ? 62
                      : 52,

                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,

                    color:
                        colors[index],

                    border: Border.all(
                      color: active
                          ? Colors.white
                          : Colors
                              .transparent,

                      width: 4,
                    ),

                    boxShadow: [

                      BoxShadow(
                        color:
                            colors[index]
                                .withOpacity(
                                    .35),

                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}