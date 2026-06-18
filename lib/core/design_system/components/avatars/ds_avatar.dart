import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/theme/extensions/gradient_extension.dart';
import '../../foundation/tokens/ds_typography.dart';

/// A circular avatar with image, initials fallback, optional story-style
/// gradient ring and online indicator. Fully theme-driven.
class DsAvatar extends StatelessWidget {
  const DsAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 44,
    this.hasRing = false,
    this.ringSeen = false,
    this.isOnline = false,
    this.onTap,
  });

  final String? imageUrl;

  /// Used to derive initials when [imageUrl] is missing.
  final String? name;
  final double size;

  /// Show a gradient story ring around the avatar.
  final bool hasRing;

  /// When true the ring is muted (already viewed).
  final bool ringSeen;
  final bool isOnline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final ringWidth = hasRing ? (size * 0.06).clamp(2.0, 3.5) : 0.0;
    final gap = hasRing ? 2.0 : 0.0;
    final inner = size - (ringWidth + gap) * 2;

    Widget avatar = Container(
      width: inner,
      height: inner,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.secondaryContainer,
        border: Border.all(color: c.surface, width: hasRing ? 1.5 : 0),
      ),
      clipBehavior: Clip.antiAlias,
      child: _content(context, inner),
    );

    if (hasRing) {
      avatar = Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ringSeen ? null : context.storyRingGradient,
          color: ringSeen ? c.border : null,
        ),
        child: Container(
          padding: EdgeInsets.all(gap),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface,
          ),
          child: avatar,
        ),
      );
    }

    if (isOnline) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.online,
                border: Border.all(color: c.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }

  Widget _content(BuildContext context, double inner) {
    final c = context.dsColors;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        width: inner,
        height: inner,
        placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
        errorWidget: (_, _, _) => _initials(context, inner),
      );
    }
    return _initials(context, inner);
  }

  Widget _initials(BuildContext context, double inner) {
    final c = context.dsColors;
    final letters = _deriveInitials(name);
    if (letters.isEmpty) {
      return Icon(Icons.person_rounded,
          size: inner * 0.55, color: c.onSecondaryContainer);
    }
    return Center(
      child: Text(
        letters,
        style: TextStyle(
          fontFamily: DsTypography.fontFamily,
          fontSize: inner * 0.38,
          fontWeight: DsTypography.semiBold,
          color: c.onSecondaryContainer,
        ),
      ),
    );
  }

  static String _deriveInitials(String? name) {
    if (name == null) return '';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }
}
