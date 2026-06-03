import 'package:flutter/material.dart';

class FloatingShadow
    extends StatelessWidget {
  final Widget child;

  const FloatingShadow({
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
                Colors.pink.withOpacity(.12),

            blurRadius: 35,
            spreadRadius: 4,
            offset: const Offset(0, 20),
          ),
        ],
      ),

      child: child,
    );
  }
}