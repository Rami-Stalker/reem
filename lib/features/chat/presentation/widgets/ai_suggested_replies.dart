import 'package:flutter/material.dart';

class AiSuggestedReplies
    extends StatelessWidget {

  final List<String> replies;

  const AiSuggestedReplies({
    super.key,
    required this.replies,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(

      height: 58,

      child: ListView.separated(

        scrollDirection: Axis.horizontal,

        physics:
            const BouncingScrollPhysics(),

        itemBuilder: (_, index) {

          return Container(

            padding:
                const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 14,
            ),

            decoration: BoxDecoration(

              borderRadius:
                  BorderRadius.circular(
                24,
              ),

              gradient:
                  const LinearGradient(

                colors: [

                  Color(0xffFFF0F5),

                  Colors.white,
                ],
              ),

              border: Border.all(

                color:
                    const Color(
                  0xffFFD1DE,
                ),
              ),
            ),

            child: Row(

              children: [

                const Icon(

                  Icons.auto_awesome,

                  color:
                      Color(
                    0xffFF5C8A,
                  ),

                  size: 18,
                ),

                const SizedBox(width: 10),

                Text(

                  replies[index],

                  style: const TextStyle(

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },

        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 14,
        ),

        itemCount:
            replies.length,
      ),
    );
  }
}