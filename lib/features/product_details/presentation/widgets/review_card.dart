import 'package:flutter/material.dart';

class ReviewCard
    extends StatelessWidget {
  final String image;
  final String name;
  final String review;
  final double rating;

  const ReviewCard({
    super.key,
    required this.image,
    required this.name,
    required this.review,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(22),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(30),

        color: Colors.white,

        boxShadow: [

          BoxShadow(
            color:
                Colors.black.withOpacity(
                    .04),

            blurRadius: 24,
            offset:
                const Offset(0, 12),
          ),
        ],
      ),

      child: Column(
        children: [

          Row(
            children: [

              /// AVATAR
              Container(
                width: 58,
                height: 58,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  image:
                      DecorationImage(
                    image:
                        NetworkImage(
                            image),

                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              /// INFO
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [

                    Text(
                      name,

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,

                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(
                        height: 8),

                    Row(
                      children:
                          List.generate(
                        5,
                        (index) {
                          return Icon(
                            Icons.star,
                            size: 18,

                            color:
                                index <
                                        rating
                                    ? Colors
                                        .amber
                                    : Colors
                                        .grey
                                        .shade300,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              /// VERIFIED
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),

                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(20),

                  color: Colors.green
                      .withOpacity(.1),
                ),

                child: const Text(
                  "Verified",

                  style: TextStyle(
                    color: Colors.green,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// REVIEW
          Text(
            review,

            style: TextStyle(
              color: Colors.grey[700],
              height: 1.8,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}