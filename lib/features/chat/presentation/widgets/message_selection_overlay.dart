import 'package:flutter/material.dart';

class MessageSelectionOverlay
    extends StatelessWidget {

  final int count;

  const MessageSelectionOverlay({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 18,
      ),

      decoration: BoxDecoration(

        color:
            Colors.white
                .withOpacity(.94),

        border: Border(

          bottom: BorderSide(

            color: Colors.black
                .withOpacity(.05),
          ),
        ),
      ),

      child: Row(

        children: [

          Text(

            "$count Selected",

            style: const TextStyle(

              fontSize: 20,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const Spacer(),

          _action(
            Icons.reply_rounded,
          ),

          const SizedBox(width: 14),

          _action(
            Icons.copy_rounded,
          ),

          const SizedBox(width: 14),

          _action(
            Icons.delete_rounded,
          ),
        ],
      ),
    );
  }

  Widget _action(
    IconData icon,
  ) {
    return Container(

      width: 48,
      height: 48,

      decoration:
          BoxDecoration(

        shape:
            BoxShape.circle,

        color:
            const Color(
          0xffFFF3F7,
        ),
      ),

      child: Icon(

        icon,

        color:
            const Color(
          0xffFF5C8A,
        ),
      ),
    );
  }
}