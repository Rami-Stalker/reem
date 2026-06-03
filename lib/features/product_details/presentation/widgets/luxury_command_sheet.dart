import 'package:flutter/material.dart';

class LuxuryCommentSheet
    extends StatelessWidget {
  const LuxuryCommentSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          MediaQuery.of(context)
                  .size
                  .height *
              .78,

      padding:
          const EdgeInsets.all(24),

      decoration: const BoxDecoration(
        color: Color(0xffFFF8FA),

        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(36),
        ),
      ),

      child: Column(
        children: [

          /// HANDLE
          Container(
            width: 70,
            height: 6,

            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                      20),

              color: Colors.grey[300],
            ),
          ),

          const SizedBox(height: 28),

          /// TITLE
          const Row(
            children: [

              Text(
                "Luxury Comments",

                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          /// COMMENTS
          Expanded(
            child: ListView.separated(
              physics:
                  const BouncingScrollPhysics(),

              itemCount: 10,

              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                    height: 18,
                  ),

              itemBuilder:
                  (context, index) {
                return Container(
                  padding:
                      const EdgeInsets
                          .all(18),

                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                                26),

                    color:
                        Colors.white,

                    boxShadow: [

                      BoxShadow(
                        color: Colors
                            .black
                            .withOpacity(
                                .03),

                        blurRadius: 18,
                        offset:
                            const Offset(
                                0,
                                8),
                      ),
                    ],
                  ),

                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      /// AVATAR
                      Container(
                        width: 54,
                        height: 54,

                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,

                          image:
                              DecorationImage(
                            image:
                                NetworkImage(
                              "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
                            ),

                            fit:
                                BoxFit.cover,
                          ),
                        ),
                      ),

                      const SizedBox(
                          width: 16),

                      /// CONTENT
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [

                            const Text(
                              "Sophia Luxury",

                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,

                                fontSize:
                                    16,
                              ),
                            ),

                            const SizedBox(
                                height:
                                    10),

                            Text(
                              "This product looks absolutely stunning and elegant ✨",

                              style:
                                  TextStyle(
                                color: Colors
                                    .grey[700],

                                height:
                                    1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          /// INPUT
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
            ),

            height: 62,

            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                      24),

              color: Colors.white,

              boxShadow: [

                BoxShadow(
                  color: Colors.black
                      .withOpacity(.03),

                  blurRadius: 18,
                ),
              ],
            ),

            child: Row(
              children: [

                Expanded(
                  child: TextField(
                    decoration:
                        InputDecoration(
                      hintText:
                          "Write a luxury comment...",

                      border:
                          InputBorder.none,

                      hintStyle:
                          TextStyle(
                        color: Colors
                            .grey[500],
                      ),
                    ),
                  ),
                ),

                Container(
                  width: 46,
                  height: 46,

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

                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}