import 'package:flutter/material.dart';

class StoryPreview
    extends StatelessWidget {

  final String image;

  const StoryPreview({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      width: 240,

      decoration: BoxDecoration(

        borderRadius:
            BorderRadius.circular(
          36,
        ),

        image: DecorationImage(
          image: NetworkImage(image),
          fit: BoxFit.cover,
        ),
      ),

      child: Stack(

        children: [

          Positioned.fill(

            child: DecoratedBox(

              decoration: BoxDecoration(

                borderRadius:
                    BorderRadius
                        .circular(36),

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
                        .withOpacity(.7),
                  ],
                ),
              ),
            ),
          ),

          const Positioned(

            bottom: 24,
            left: 24,

            child: Text(

              "Your Story",

              style: TextStyle(

                color: Colors.white,

                fontSize: 22,

                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}