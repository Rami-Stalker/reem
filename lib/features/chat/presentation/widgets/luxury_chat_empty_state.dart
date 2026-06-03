import 'package:flutter/material.dart';

class LuxuryChatEmptyState
    extends StatelessWidget {

  const LuxuryChatEmptyState({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(

      child: Column(

        mainAxisAlignment:
            MainAxisAlignment
                .center,

        children: [

          Container(

            width: 180,
            height: 180,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              color: Colors.pink
                  .withOpacity(.08),
            ),

            child: const Icon(

              Icons.chat_bubble_rounded,

              size: 80,

              color:
                  Color(
                0xffFF5C8A,
              ),
            ),
          ),

          const SizedBox(height: 32),

          const Text(

            "No Conversations Yet",

            style: TextStyle(

              fontSize: 28,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          Padding(

            padding:
                const EdgeInsets.symmetric(
              horizontal: 46,
            ),

            child: Text(

              "Start elegant conversations with your customers and build premium relationships ✨",

              textAlign:
                  TextAlign.center,

              style: TextStyle(

                color:
                    Colors.grey[600],

                height: 1.7,

                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}