import 'package:flutter/material.dart';

class NeonGlowEffect
    extends StatelessWidget {
  final Widget child;

  const NeonGlowEffect({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [

          BoxShadow(
            color:
                Colors.pink.withOpacity(.25),

            blurRadius: 35,
            spreadRadius: 5,
          ),

          BoxShadow(
            color:
                Colors.purple.withOpacity(.18),

            blurRadius: 45,
            spreadRadius: 10,
          ),
        ],
      ),

      child: child,
    );
  }
}