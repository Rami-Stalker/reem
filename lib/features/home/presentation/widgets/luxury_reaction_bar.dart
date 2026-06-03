import 'package:flutter/material.dart';

class LuxuryReactionBar
    extends StatelessWidget {
  final String likes;
  final String comments;

  const LuxuryReactionBar({
    super.key,
    required this.likes,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        const Icon(
          Icons.favorite_rounded,
          color: Colors.pinkAccent,
          size: 22,
        ),

        const SizedBox(width: 8),

        Text(
          likes,

          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(width: 20),

        const Icon(
          Icons.mode_comment_outlined,
          color: Colors.white,
          size: 20,
        ),

        const SizedBox(width: 8),

        Text(
          comments,

          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const Spacer(),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),

          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
                    20),

            gradient:
                const LinearGradient(
              colors: [
                Color(0xffFF9EB5),
                Color(0xffFF5C8A),
              ],
            ),
          ),

          child: const Row(
            children: [

              Icon(
                Icons.shopping_bag,
                color: Colors.white,
                size: 18,
              ),

              SizedBox(width: 8),

              Text(
                "Buy",

                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}