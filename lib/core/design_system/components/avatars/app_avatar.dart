import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// A profile portrait inside a gradient ring, with an optional hero.
///
/// The ring and the hero are the whole reason this exists alongside [DsAvatar];
/// the picture itself is drawn by [DsAvatar], so loading, initials and the
/// online dot behave the same everywhere.
///
/// It used to fall back to a **fixed Unsplash photograph of a stranger** when
/// no [imageUrl] was given — which is what the settings header passed, so every
/// woman in Reem saw the same borrowed face where her own belonged. A missing
/// picture now falls back to her initials, and to nothing at all if even the
/// name is unknown.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.radius,
    this.imageUrl,
    this.name,
    this.heroTag = 'profile',
    this.onTap,
  });

  final double radius;
  final String? imageUrl;

  /// Used to derive the initials shown when there is no picture.
  final String? name;
  final Object? heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    final avatar = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: context.primaryGradient,
        boxShadow: context.luxuryShadow,
      ),
      child: DsAvatar(
        imageUrl: (url == null || url.isEmpty) ? null : url,
        name: name,
        size: radius * 2,
        onTap: onTap,
      ),
    );

    if (heroTag == null) return avatar;
    return Hero(tag: heroTag!, child: avatar);
  }
}
