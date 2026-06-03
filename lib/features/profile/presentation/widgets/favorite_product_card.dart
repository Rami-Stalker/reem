import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_names.dart';

class FavoriteProductCard extends StatelessWidget {
  const FavoriteProductCard({super.key, required this.index});

  final int index;

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
            Image.network(
              'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&sig=$index',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colors.onSurface.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: context.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: context.softShadow,
                ),
                child: Icon(Icons.favorite_rounded, color: colors.onPrimary, size: 20),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ClipRRect(
                borderRadius: DsRadius.borderLg,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: context.ds.glassGradient,
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silk Dress',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: DsTypography.semiBold,
                          ),
                        ),
                        Text(
                          '\$${89 + index * 10}',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: DsTypography.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
