import 'package:flutter/material.dart';

class LuxuryRatingBar
    extends StatelessWidget {
  const LuxuryRatingBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        Row(
          children: List.generate(
            5,
            (index) {
              return const Padding(
                padding:
                    EdgeInsetsDirectional.only(
                  end: 4,
                ),

                child: Icon(
                  Icons.star_rounded,
                  color:
                      Colors.amber,
                  size: 24,
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        const Text(
          "4.9",

          style: TextStyle(
            fontWeight:
                FontWeight.bold,

            fontSize: 18,
          ),
        ),

        const SizedBox(width: 10),

        Text(
          "(2.4k reviews)",

          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}