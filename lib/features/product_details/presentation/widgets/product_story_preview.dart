import 'package:flutter/material.dart';

class ProductStoryPreview
    extends StatelessWidget {
  const ProductStoryPreview({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          "Luxury Stories",

          style: TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 110,

          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,

            itemCount: 8,

            separatorBuilder:
                (_, __) =>
                    const SizedBox(
                      width: 18,
                    ),

            itemBuilder:
                (context, index) {
              return Column(
                children: [

                  Container(
                    padding:
                        const EdgeInsets
                            .all(3),

                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,

                      gradient:
                          LinearGradient(
                        colors: [
                          Color(
                              0xffFF9EB5),
                          Color(
                              0xffFF5C8A),
                        ],
                      ),
                    ),

                    child: Container(
                      width: 74,
                      height: 74,

                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape
                                .circle,

                        border:
                            Border.all(
                          color:
                              Colors
                                  .white,
                          width: 3,
                        ),

                        image:
                            const DecorationImage(
                          image:
                              NetworkImage(
                            "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
                          ),

                          fit:
                              BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                      height: 10),

                  const Text(
                    "Luxury",

                    style: TextStyle(
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}