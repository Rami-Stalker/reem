  import 'package:flutter/material.dart';

class UnreadBadge
    extends StatelessWidget {

  final int count;

  const UnreadBadge({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration:
          const BoxDecoration(

        gradient:
            LinearGradient(

          colors: [

            Color(0xffFF9EB5),
            Color(0xffFF5C8A),
          ],
        ),

        borderRadius:
            BorderRadius.all(
          Radius.circular(30),
        ),
      ),

      child: Text(

        "$count",

        style: const TextStyle(

          color: Colors.white,

          fontWeight:
              FontWeight.bold,

          fontSize: 12,
        ),
      ),
    );
  }
}