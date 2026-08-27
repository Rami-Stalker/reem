import 'package:flutter/material.dart';

class MessageBubble
    extends StatelessWidget {

  final bool isMe;

  final String message;

  const MessageBubble({
    super.key,
    required this.isMe,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(

      alignment:
          isMe
              // Directional, not absolute: the sender's own bubble sits on
              // the trailing edge of the reading direction, which flips with
              // the locale instead of staying pinned to a physical side.
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,

      child: Container(

        constraints:
            const BoxConstraints(
          maxWidth: 320,
        ),

        padding:
            const EdgeInsets.all(
          18,
        ),

        decoration: BoxDecoration(

          gradient:
              isMe
                  ? const LinearGradient(
                      colors: [

                        Color(
                            0xffFF9EB5),

                        Color(
                            0xffFF5C8A),
                      ],
                    )
                  : null,

          color:
              isMe
                  ? null
                  : Colors.white,

          borderRadius:
              BorderRadius.only(

            topLeft:
                const Radius.circular(
              28,
            ),

            topRight:
                const Radius.circular(
              28,
            ),

            bottomLeft:
                Radius.circular(
              isMe ? 28 : 6,
            ),

            bottomRight:
                Radius.circular(
              isMe ? 6 : 28,
            ),
          ),
        ),

        child: Text(

          message,

          style: TextStyle(

            color:
                isMe
                    ? Colors.white
                    : Colors.black87,

            height: 1.7,

            fontSize: 15,
          ),
        ),
      ),
    );
  }
}