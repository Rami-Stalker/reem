import 'package:flutter/material.dart';

class InteractiveReactionBar
    extends StatelessWidget {
  const InteractiveReactionBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        _item(
          Icons.favorite,
          '24K',
          Colors.pink,
        ),

        const SizedBox(width: 24),

        _item(
          Icons.mode_comment,
          '1.2K',
          Colors.purple,
        ),

        const SizedBox(width: 24),

        _item(
          Icons.share,
          '800',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _item(
    IconData icon,
    String value,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),

        color: color.withOpacity(.10),
      ),

      child: Row(
        children: [

          Icon(
            icon,
            color: color,
            size: 20,
          ),

          const SizedBox(width: 10),

          Text(
            value,

            style: TextStyle(
              color: color,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}