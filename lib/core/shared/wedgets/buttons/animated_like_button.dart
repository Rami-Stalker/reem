import 'package:flutter/material.dart';

class AnimatedLikeButton
    extends StatefulWidget {
  const AnimatedLikeButton({
    super.key,
  });

  @override
  State<AnimatedLikeButton>
      createState() =>
          _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState
    extends State<AnimatedLikeButton> {
  bool liked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          liked = !liked;
        });
      },

      child: AnimatedScale(
        duration:
            const Duration(
                milliseconds: 300),

        scale: liked ? 1.25 : 1,

        child: Icon(
          liked
              ? Icons.favorite
              : Icons.favorite_border,

          color:
              liked ? Colors.pink : Colors.white,

          size: 30,
        ),
      ),
    );
  }
}