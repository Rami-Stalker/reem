import 'package:flutter/material.dart';

class StoryShareCard
    extends StatelessWidget {

  const StoryShareCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      width: 280,

      decoration: BoxDecoration(

        borderRadius:
            BorderRadius.circular(
          34,
        ),

        image: const DecorationImage(

          image: NetworkImage(
            "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",
          ),

          fit: BoxFit.cover,
        ),
      ),

      child: Stack(

        children: [

          Positioned.fill(

            child: DecoratedBox(

              decoration:
                  BoxDecoration(

                borderRadius:
                    BorderRadius
                        .circular(34),

                gradient:
                    LinearGradient(

                  begin:
                      Alignment.topCenter,

                  end:
                      Alignment
                          .bottomCenter,

                  colors: [

                    Colors.transparent,

                    Colors.black
                        .withOpacity(.75),
                  ],
                ),
              ),
            ),
          ),

          Positioned(

            left: 20,
            bottom: 24,

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                const Text(

                  "Luxury Story",

                  style: TextStyle(

                    color:
                        Colors.white,

                    fontSize: 22,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(

                  "Shared from your premium feed ✨",

                  style: TextStyle(

                    color: Colors.white
                        .withOpacity(.9),

                    height: 1.5,
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