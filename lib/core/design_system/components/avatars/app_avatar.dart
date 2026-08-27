import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

class AppAvatar extends StatelessWidget {
  final double radius;
  final String? imageUrl;
  final Object? heroTag;

  const AppAvatar({
    super.key,
    required this.radius,
    this.imageUrl,
    this.heroTag = 'profile',
  });

  static const _fallback =
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330';

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: context.primaryGradient,
        boxShadow: context.luxuryShadow,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(
          (imageUrl != null && imageUrl!.isNotEmpty) ? imageUrl! : _fallback,
        ),
      ),
    );

    if (heroTag == null) return avatar;
    return Hero(tag: heroTag!, child: avatar);
  }
}
