import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class AppAvatar extends StatelessWidget {
  final double radius;
  const AppAvatar({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'profile',
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: context.primaryGradient,
          boxShadow: context.luxuryShadow,
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
          ),
        ),
      ),
    );
  }
}
