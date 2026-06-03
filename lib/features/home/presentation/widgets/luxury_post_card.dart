import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/buttons/animated_like_button.dart';

/// Compact post card for horizontal trending carousel.
class LuxuryPostCard extends StatelessWidget {
  const LuxuryPostCard({
    super.key,
    required this.image,
    required this.title,
    required this.likes,
    required this.comments,
  });

  final String image;
  final String title;
  final String likes;
  final String comments;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxxl,
        boxShadow: context.luxuryShadow,
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxxl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(image, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colors.onSurface.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Positioned(
              left: DsSpacing.md,
              right: DsSpacing.md,
              bottom: DsSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: DsTypography.bold,
                      fontSize: DsTypography.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const AnimatedLikeButton(),
                      const SizedBox(width: 8),
                      Text(
                        likes,
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.9),
                          fontSize: DsTypography.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 18, color: colors.onPrimary.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      Text(
                        comments,
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.9),
                          fontSize: DsTypography.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.96, 0.96));
  }
}
