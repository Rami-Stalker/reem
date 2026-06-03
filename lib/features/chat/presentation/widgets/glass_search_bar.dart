import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSearchBar
    extends StatelessWidget {

  const GlassSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(

      borderRadius:
          BorderRadius.circular(
        28,
      ),

      child: BackdropFilter(

        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),

        child: Container(

          padding:
              const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 6,
          ),

          decoration: BoxDecoration(

            color:
                Colors.white
                    .withOpacity(.7),

            borderRadius:
                BorderRadius.circular(
              28,
            ),

            border: Border.all(
              color: Colors.white
                  .withOpacity(.25),
            ),
          ),

          child: TextField(

            decoration: InputDecoration(

              icon: Icon(
                Icons.search_rounded,
                color: Colors.grey[600],
              ),

              hintText:
                  "Search conversations...",

              hintStyle: TextStyle(
                color: Colors.grey[500],
              ),

              border:
                  InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}