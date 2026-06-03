import 'package:flutter/material.dart';

class ChatThemeSelector
    extends StatelessWidget {

  const ChatThemeSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final themes = [

      [
        const Color(0xffFF9EB5),
        const Color(0xffFF5C8A),
      ],

      [
        const Color(0xff6A85F1),
        const Color(0xff8D6BFF),
      ],

      [
        const Color(0xff111111),
        const Color(0xff333333),
      ],

      [
        const Color(0xffFFCC70),
        const Color(0xffFF8C42),
      ],
    ];

    return SizedBox(

      height: 86,

      child: ListView.separated(

        scrollDirection:
            Axis.horizontal,

        itemBuilder:
            (_, index) {

          return Container(

            width: 86,
            height: 86,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              gradient:
                  LinearGradient(

                colors:
                    themes[index],
              ),

              boxShadow: [

                BoxShadow(

                  color: themes[index]
                          .first
                          .withOpacity(
                              .35),

                  blurRadius: 18,
                ),
              ],
            ),
          );
        },

        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 18,
        ),

        itemCount:
            themes.length,
      ),
    );
  }
}