import 'package:flutter/material.dart';

class ProductShareMessage
    extends StatelessWidget {

  const ProductShareMessage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Align(

      alignment:
          Alignment.centerLeft,

      child: Container(

        width: 290,

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            30,
          ),

          boxShadow: [

            BoxShadow(

              color: Colors.black
                  .withOpacity(.05),

              blurRadius: 18,
            ),
          ],
        ),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment
                  .start,

          children: [

            ClipRRect(

              borderRadius:
                  const BorderRadius.vertical(

                top:
                    Radius.circular(
                  30,
                ),
              ),

              child: Image.network(

                "https://images.unsplash.com/photo-1529139574466-a303027c1d8b",

                height: 240,

                width: double.infinity,

                fit: BoxFit.cover,
              ),
            ),

            Padding(

              padding:
                  const EdgeInsets.all(
                20,
              ),

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [

                  const Text(

                    "Luxury Pink Dress",

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(

                    "Elegant premium fashion piece crafted for luxury women ✨",

                    style: TextStyle(

                      color:
                          Colors.grey[600],

                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(

                    children: [

                      const Text(

                        "\$240",

                        style: TextStyle(

                          fontSize: 22,

                          fontWeight:
                              FontWeight.bold,

                          color:
                              Color(
                            0xffFF5C8A,
                          ),
                        ),
                      ),

                      const Spacer(),

                      Container(

                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),

                        decoration:
                            BoxDecoration(

                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),

                          gradient:
                              const LinearGradient(

                            colors: [

                              Color(
                                  0xffFF9EB5),

                              Color(
                                  0xffFF5C8A),
                            ],
                          ),
                        ),

                        child: const Text(

                          "Shop Now",

                          style: TextStyle(

                            color:
                                Colors.white,

                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}