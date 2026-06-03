import 'package:flutter/material.dart';

class ChatMessageMenu
    extends StatelessWidget {

  const ChatMessageMenu({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      width: 220,

      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration: BoxDecoration(

        color:
            Colors.white
                .withOpacity(.96),

        borderRadius:
            BorderRadius.circular(
          28,
        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black
                .withOpacity(.08),

            blurRadius: 30,
          ),
        ],
      ),

      child: Column(

        mainAxisSize:
            MainAxisSize.min,

        children: [

          _item(
            Icons.reply_rounded,
            "Reply",
          ),

          _item(
            Icons.favorite_rounded,
            "React",
          ),

          _item(
            Icons.push_pin_rounded,
            "Pin",
          ),

          _item(
            Icons.copy_rounded,
            "Copy",
          ),

          _item(
            Icons.delete_rounded,
            "Delete",
          ),
        ],
      ),
    );
  }

  Widget _item(
    IconData icon,
    String title,
  ) {
    return Padding(

      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child: Row(

        children: [

          Icon(

            icon,

            color:
                const Color(
              0xffFF5C8A,
            ),
          ),

          const SizedBox(width: 14),

          Text(

            title,

            style: const TextStyle(

              fontSize: 16,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}