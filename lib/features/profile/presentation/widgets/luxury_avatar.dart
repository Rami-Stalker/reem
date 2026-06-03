import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class LuxuryAvatar extends StatelessWidget {
  const LuxuryAvatar({super.key});

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
        child: const CircleAvatar(
          radius: 58,
          backgroundImage: NetworkImage(
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
          ),
        ),
      ),
    );
  }
}
