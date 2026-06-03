import 'package:flutter/material.dart';

class LuxuryStoryList
    extends StatelessWidget {

  const LuxuryStoryList({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(

      height: 128,

      child: ListView.separated(

        padding:
            const EdgeInsets.symmetric(
          horizontal: 22,
        ),

        scrollDirection:
            Axis.horizontal,

        physics:
            const BouncingScrollPhysics(),

        itemBuilder:
            (_, index) {

          return Column(

            children: [

              Container(

                padding:
                    const EdgeInsets.all(
                  4,
                ),

                decoration:
                    BoxDecoration(

                  shape:
                      BoxShape.circle,

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

                child: CircleAvatar(

                  radius: 36,

                  backgroundColor:
                      Colors.white,

                  child: CircleAvatar(

                    radius: 32,

                    backgroundImage:
                        NetworkImage(

                      "https://picsum.photos/200/${index + 20}",
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(

                index == 0
                    ? "Your Story"
                    : "Luxury ${index + 1}",

                style: const TextStyle(

                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          );
        },

        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 18,
        ),

        itemCount: 10,
      ),
    );
  }
}