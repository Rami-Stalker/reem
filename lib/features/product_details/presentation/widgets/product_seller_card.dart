import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/presentation/widgets/message_seller_button.dart';

/// Who is actually selling this piece, and the way to ask her about it.
///
/// The catalogue is shared — one product entry can carry offers from several
/// boutiques — so the card names the boutique behind the offer she is looking
/// at, and starts the conversation against *that* seller rather than letting
/// the server pick the cheapest.
class ProductSellerCard extends StatelessWidget {
  const ProductSellerCard({super.key, required this.product, this.offer});

  final Product product;

  /// The offer she has selected on the page. Null falls back to the cheapest.
  final SellerOffer? offer;

  @override
  Widget build(BuildContext context) {
    final selected = offer ?? product.bestOffer;
    final seller = selected?.seller;
    if (seller == null) return const SizedBox.shrink();

    final c = context.dsColors;
    final l10n = context.l10n;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.soldBy,
            style: context.dsText.label.copyWith(
              color: c.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              DsAvatar(
                imageUrl: seller.imageUrl,
                name: seller.name,
                size: 52,
                onTap: () => context.push(RoutePaths.userProfileOf(seller.id)),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seller.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.tileTitle
                          .copyWith(fontWeight: DsTypography.bold),
                    ),
                    DsGaps.vXxxs,
                    GestureDetector(
                      onTap: () =>
                          context.push(RoutePaths.userProfileOf(seller.id)),
                      child: Text(
                        l10n.visitStore,
                        style: context.dsText.caption.copyWith(
                          color: c.primary,
                          fontWeight: DsTypography.semiBold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          MessageSellerButton(
            label: l10n.askAboutThisPiece,
            request: ChatStartRequest.product(
              productId: product.id,
              sellerId: seller.id,
            ),
          ),
        ],
      ),
    );
  }
}
