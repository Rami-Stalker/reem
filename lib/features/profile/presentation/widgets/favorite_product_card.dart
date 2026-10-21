import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
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
              // The product's own like, not a decoration.
              //
              // This corner held a filled rose heart that did nothing: every
              // piece on this screen is saved by definition, so the icon
              // restated the screen's own title and was the one control on a
              // card that could not be pressed. The like is a different fact
              // from the save, and this is the only surface where the two sit
              // side by side — the shelf is hers, the applause is public.
              PositionedDirectional(
                top: 12,
                end: 12,
                child:
                    DsProductActions.of(
                      context,
                      product,
                      DsProductSurface.tile,
                    ) ??
                    const SizedBox.shrink(),
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
                      padding: const EdgeInsets.all(DsSpacing.sm),
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
                            style: context.dsText.body.semibold.tint(colors.onSurface),
                          ),
                          DsGaps.vXxs,
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.price?.format() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.dsText.body.bold.tint(colors.primary),
                                ),
                              ),
                              Icon(
                                Icons.star_rounded,
                                color: colors.warning,
                                size: 16,
                              ),
                              Text(
                                product.rating.toStringAsFixed(1),
                                style: context.dsText.body.medium.tint(colors.onSurface),
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
    return AuthorizedMediaImage(
      url: url!,
      variantWidth: MediaVariants.thumbnail,
    );
  }
}
