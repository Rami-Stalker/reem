import 'package:flutter/material.dart';
import 'package:reem/core/shared/wedgets/backgrounds/luxury_blurred_background.dart';


class ChatMediaGalleryScreen
    extends StatelessWidget {

  const ChatMediaGalleryScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final images = [

      "https://images.unsplash.com/photo-1529139574466-a303027c1d8b",

      "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",

      "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df",

      "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
    ];

    return Scaffold(

      body:
       LuxuryBlurredBackground(

        child: 
        SafeArea(

          child: Padding(

            padding:
                const EdgeInsets.all(
              22,
            ),

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                Row(

                  children: [

                    GestureDetector(

                      onTap: () {
                        Navigator.pop(
                            context);
                      },

                      child: Container(

                        width: 56,
                        height: 56,

                        decoration:
                            BoxDecoration(

                          shape:
                              BoxShape.circle,

                          color:
                              Colors.white,
                        ),

                        child: const Icon(
                          Icons
                              .arrow_back_ios_new_rounded,
                        ),
                      ),
                    ),

                    const SizedBox(width: 18),

                    const Text(

                      "Shared Media",

                      style: TextStyle(

                        fontSize: 30,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Expanded(

                  child: GridView.builder(

                    physics:
                        const BouncingScrollPhysics(),

                    itemCount:
                        images.length,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(

                      crossAxisCount:
                          2,

                      crossAxisSpacing:
                          18,

                      mainAxisSpacing:
                          18,

                      childAspectRatio:
                          .72,
                    ),

                    itemBuilder:
                        (_, index) {

                      return Hero(

                        tag:
                            images[index],

                        child:
                            ClipRRect(

                          borderRadius:
                              BorderRadius
                                  .circular(
                            32,
                          ),

                          child:
                              Image.network(

                            images[index],

                            fit:
                                BoxFit.cover,
                          ),
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