import 'dart:ui';

import 'package:flutter/material.dart';

class EmojiReactionSheet
    extends StatelessWidget {

  const EmojiReactionSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final emojis = [

      "❤️",
      "😍",
      "🔥",
      "😂",
      "😮",
      "🥺",
      "👏",
      "✨",
    ];

    return ClipRRect(

      borderRadius:
          const BorderRadius.vertical(
        top: Radius.circular(38),
      ),

      child: BackdropFilter(

        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),

        child: Container(

          padding:
              const EdgeInsets.all(
            28,
          ),

          decoration:
              BoxDecoration(

            color: Colors.white
                .withOpacity(.92),

            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(
                38,
              ),
            ),
          ),

          child: Column(

            mainAxisSize:
                MainAxisSize.min,

            children: [

              Container(

                width: 80,
                height: 6,

                decoration:
                    BoxDecoration(

                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),

                  color:
                      Colors.grey[300],
                ),
              ),

              const SizedBox(height: 28),

              Wrap(

                spacing: 18,
                runSpacing: 18,

                children: emojis.map(
                  (emoji) {

                    return GestureDetector(

                      onTap: () {},

                      child: AnimatedContainer(

                        duration:
                            const Duration(
                          milliseconds:
                              300,
                        ),

                        width: 72,
                        height: 72,

                        decoration:
                            BoxDecoration(

                          shape:
                              BoxShape.circle,

                          color:
                              const Color(
                            0xffFFF3F7,
                          ),
                        ),

                        child: Center(

                          child: Text(

                            emoji,

                            style:
                                const TextStyle(
                              fontSize: 32,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}