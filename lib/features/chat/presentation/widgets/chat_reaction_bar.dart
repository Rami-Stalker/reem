import 'package:flutter/material.dart';

class ChatReactionBar
    extends StatelessWidget {

  const ChatReactionBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final reactions = [
      "❤️",
      "🔥",
      "😍",
      "✨",
      "😂",
    ];

    return Container(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),

      decoration:
          BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          40,
        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black
                .withOpacity(.06),

            blurRadius: 20,
          ),
        ],
      ),

      child: Row(

        mainAxisSize:
            MainAxisSize.min,

        children: List.generate(
          reactions.length,
          (index) {

            return Padding(

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 6,
              ),

              child: AnimatedContainer(

                duration:
                    const Duration(
                  milliseconds: 250,
                ),

                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(

                  shape:
                      BoxShape.circle,

                  color: Colors.pink
                      .withOpacity(.08),
                ),

                child: Center(

                  child: Text(

                    reactions[index],

                    style:
                        const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}