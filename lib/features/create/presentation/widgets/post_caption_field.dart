import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';


class PostCaptionField
    extends StatelessWidget {

  const PostCaptionField({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding:
          const EdgeInsets.all(24),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          DsRadius.xl,
        ),

        boxShadow:
            DsShadows
                .medium(DsColors.primary600),
      ),

      child: TextField(

        maxLines: 7,

        decoration: InputDecoration(

          hintText:
              "Write your luxurious caption...",

          hintStyle: TextStyle(
            color: Colors.grey[500],
          ),

          border:
              InputBorder.none,
        ),

        style: const TextStyle(
          height: 1.8,
          fontSize: 16,
        ),
      ),
    );
  }
}