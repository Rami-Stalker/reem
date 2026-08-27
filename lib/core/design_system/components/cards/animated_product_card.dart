import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../design_system.dart';

class AnimatedProductCard extends StatelessWidget {
  const AnimatedProductCard({
    super.key,
    required this.image,
    required this.title,
    required this.price,
  });

  final String image;
  final String title;
  final String price;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.productDetails),
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
                    colors.onSurface.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            const Positioned(top: 14, right: 14, child: AnimatedLikeButton()),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: GlassContainer(
                borderRadius: DsRadius.xl,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: DsTypography.bold,
                        fontSize: DsTypography.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: DsTypography.bold,
                        fontSize: DsTypography.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}
