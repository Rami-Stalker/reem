import 'package:flutter/material.dart';

class ProductSizeSelector
    extends StatefulWidget {
  const ProductSizeSelector({
    super.key,
  });

  @override
  State<ProductSizeSelector>
      createState() =>
          _ProductSizeSelectorState();
}

class _ProductSizeSelectorState
    extends State<ProductSizeSelector> {
  int selected = 1;

  final sizes = [
    "XS",
    "S",
    "M",
    "L",
    "XL",
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          "Select Size",

          style: TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: List.generate(
            sizes.length,
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
                    right: 14,
                  ),

                  width: 58,
                  height: 58,

                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                                18),

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
                        : Colors.white,

                    boxShadow: [

                      BoxShadow(
                        color: active
                            ? Colors
                                .pink
                                .withOpacity(
                                    .25)
                            : Colors
                                .black
                                .withOpacity(
                                    .04),

                        blurRadius: 20,
                        offset:
                            const Offset(
                                0,
                                10),
                      ),
                    ],
                  ),

                  child: Center(
                    child: Text(
                      sizes[index],

                      style: TextStyle(
                        color: active
                            ? Colors
                                .white
                            : Colors
                                .black,

                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
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