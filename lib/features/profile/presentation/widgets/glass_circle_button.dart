import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCircleButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),

        child: Container(
          width: 48,
          height: 48,

          decoration: BoxDecoration(
            color:
                Colors.white.withOpacity(.18),
            shape: BoxShape.circle,
          ),

          child: IconButton(
            onPressed: onTap,

            icon: Icon(
              icon,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}