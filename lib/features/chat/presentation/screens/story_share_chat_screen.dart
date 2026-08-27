import 'package:flutter/material.dart';
import 'package:reem/core/design_system/effects/backgrounds/luxury_blurred_background.dart';


class StoryShareChatScreen
    extends StatelessWidget {

  const StoryShareChatScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: LuxuryBlurredBackground(

        child: SafeArea(

          child: Padding(

            padding:
                const EdgeInsets.all(
              22,
            ),

            child: Column(

              children: [

                Row(

                  children: [

                    GestureDetector(

                      onTap: () {
                        Navigator.pop(
                            context);
                      },

                      child: Container(

                        width: 54,
                        height: 54,

                        decoration:
                            BoxDecoration(

                          shape:
                              BoxShape.circle,

                          color:
                              Colors.white,
                        ),

                        child: const Icon(
                          Icons.close,
                        ),
                      ),
                    ),

                    const SizedBox(width: 18),

                    const Text(

                      'Share Story',

                      style: TextStyle(

                        fontSize: 30,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 34),

                Expanded(

                  child: ListView.builder(

                    physics:
                        const BouncingScrollPhysics(),

                    itemCount: 10,

                    itemBuilder:
                        (_, index) {

                      return Container(

                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 18,
                        ),

                        padding:
                            const EdgeInsets
                                .all(16),

                        decoration:
                            BoxDecoration(

                          color: Colors
                              .white
                              .withOpacity(
                                  .7),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            28,
                          ),
                        ),

                        child: Row(

                          children: [

                            CircleAvatar(

                              radius: 32,

                              backgroundImage:
                                  NetworkImage(

                                'https://picsum.photos/200/$index',
                              ),
                            ),

                            const SizedBox(
                                width: 18),

                            Expanded(

                              child: Column(

                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Text(

                                    'Luxury User ${index + 1}',

                                    style:
                                        const TextStyle(

                                      fontWeight:
                                          FontWeight
                                              .bold,

                                      fontSize:
                                          17,
                                    ),
                                  ),

                                  const SizedBox(
                                      height:
                                          6),

                                  Text(

                                    'Tap to share story ✨',

                                    style:
                                        TextStyle(

                                      color:
                                          Colors
                                                  .grey[
                                              600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(

                              width: 52,
                              height: 52,

                              decoration:
                                  const BoxDecoration(

                                shape:
                                    BoxShape
                                        .circle,

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

                              child:
                                  const Icon(

                                Icons
                                    .send_rounded,

                                color: Colors
                                    .white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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