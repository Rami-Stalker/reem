import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_names.dart';
import 'package:reem/core/shared/entities/product.dart';

class FavoriteProductCard extends StatelessWidget {
  const FavoriteProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Semantics(
      button: true,
      label: context.l10n.a11yOpen(product.title),
      child: GestureDetector(
        onTap: () => context.pushNamed(
          RouteNames.productDetails,
          queryParameters: {'id': product.id},
        ),
        child: ClipRRect(
          borderRadius: DsRadius.borderXxxl,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ProductImage(url: product.coverUrl),
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
                  child: Icon(
                    Icons.favorite_rounded,
                    color: colors.onPrimary,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: ClipRRect(
                  borderRadius: DsRadius.borderLg,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: DsBlur.light,
                      sigmaY: DsBlur.light,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: context.ds.glassGradient,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: DsTypography.semiBold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.price?.format() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: DsTypography.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.star_rounded,
                                color: colors.warning,
                                size: 16,
                              ),
                              Text(
                                product.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: DsTypography.medium,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    if (url == null || url!.isEmpty) {
      return ColoredBox(
        color: colors.surfaceVariant,
        child: Icon(
          Icons.image_outlined,
          color: colors.onSurfaceVariant,
          size: 40,
        ),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: colors.surfaceVariant,
        child: Icon(
          Icons.broken_image_outlined,
          color: colors.onSurfaceVariant,
          size: 40,
        ),
      ),
    );
  }
}
