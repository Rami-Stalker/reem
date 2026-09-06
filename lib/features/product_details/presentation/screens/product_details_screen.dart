import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/product_variant.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:reem/features/closet/presentation/widgets/closet_pairing_panel.dart';
import 'package:reem/features/intelligence/presentation/widgets/product_intelligence_notes.dart';
import 'package:reem/features/product_details/presentation/widgets/product_buy_bar.dart';
import 'package:reem/features/product_details/presentation/widgets/product_detail_body.dart';
import 'package:reem/features/product_details/presentation/widgets/product_gallery_header.dart';
import 'package:reem/features/product_details/presentation/widgets/product_headline.dart';
import 'package:reem/features/product_details/presentation/widgets/product_option_pickers.dart';
import 'package:reem/features/product_details/presentation/widgets/product_price_block.dart';
import 'package:reem/features/product_details/presentation/widgets/product_reviews_section.dart';
import 'package:reem/features/product_details/presentation/widgets/product_seller_card.dart';
import 'package:reem/features/product_details/presentation/widgets/related_products_rail.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';
import 'package:reem/features/visual_search/presentation/widgets/visually_similar_rail.dart';

/// The product page.
///
/// It used to be a template: a fixed Unsplash photograph, "Elegant Silk Midi
/// Dress", `$240` struck through `$420`, a size row of XS–XL and an "add to
/// cart" button that flipped to a tick and wrote nothing. The provider behind
/// it fetched the real product and the screen ignored the result.
///
/// Everything on the page now comes from that product: its photographs, its
/// price from the boutique she selects, its real variants, and a buy bar that
/// posts to the cart. The selection — which seller, which option, how many —
/// lives here, because it is what the whole page is arranged around.
class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  String? _offerId;
  String? _variantId;
  int _quantity = 1;

  /// Her own like on this piece. Seeded from the server's answer the first
  /// time the product arrives, then owned here so the heart responds to the
  /// tap rather than to a round trip.
  bool? _liked;
  bool _likeInFlight = false;

  /// Saves the piece to «المفضّلة», for real.
  ///
  /// The heart over the photograph was decoration: `ProductGalleryHeader`
  /// takes an `onToggleLike`, and this screen never passed one, so the icon
  /// drew the server's state and swallowed every tap.
  Future<void> _toggleLike(Product product) async {
    if (_likeInFlight) return;
    final signedIn = await requireAuthenticatedUser(
      context,
      ref,
      title: context.l10n.signInToInteract,
      message: context.l10n.signInToInteractBody,
      from: RoutePaths.productDetailsOf(product.id),
    );
    if (!signedIn || !mounted) return;

    final was = _liked ?? product.isLiked;
    setState(() {
      _liked = !was;
      _likeInFlight = true;
    });

    final result = await ref.read(toggleFavoriteUseCaseProvider).call(
      product.id,
    );
    if (!mounted) return;
    setState(() {
      _likeInFlight = false;
      if (result case Error()) _liked = was;
    });

    if (result case Error()) {
      DsSnackbar.error(context, context.l10n.actionDidNotSave);
      return;
    }
    // «المفضّلة» is a list she can open from the same session, so it is
    // refreshed rather than left to go stale behind her.
    unawaited(ref.read(favoritesNotifierProvider.notifier).load());
  }

  /// The offer she is buying from: her pick, or the cheapest buyable one.
  SellerOffer? _selectedOffer(Product product) =>
      product.offerById(_offerId) ??
      product.offers.where((o) => o.isBuyable).firstOrNull ??
      product.bestOffer;

  OfferVariant? _selectedVariant(SellerOffer? offer) {
    if (offer == null || offer.variants.isEmpty) return null;
    return offer.variantById(_variantId) ??
        offer.variants.where((v) => v.inStock).firstOrNull ??
        offer.variants.first;
  }

  void _selectOffer(SellerOffer offer) => setState(() {
        _offerId = offer.id;
        // The previous variant belonged to the previous seller's stock.
        _variantId = null;
        _quantity = offer.minOrderQty.clamp(1, 999);
      });

  @override
  Widget build(BuildContext context) {
    final productId = widget.productId;
    final hasId = productId != null && productId.isNotEmpty;
    final state = hasId
        ? ref.watch(productDetailsNotifierProvider(productId))
        : null;
    final product = state?.product;

    if (state?.isLoading == true && product == null) {
      return const Scaffold(body: Center(child: DsLoadingIndicator()));
    }

    if (product == null) {
      return Scaffold(
        appBar: ReemAppBar(title: context.l10n.error),
        body: DsErrorState(
          message: state?.error,
          onRetry: hasId
              ? () => ref
                    .read(productDetailsNotifierProvider(productId).notifier)
                    .load(productId)
              : null,
        ),
      );
    }

    final offer = _selectedOffer(product);
    final variant = _selectedVariant(offer);
    final maxQuantity = _maxQuantity(offer, variant);

    return Scaffold(
      backgroundColor: context.dsColors.background,
      bottomNavigationBar: ProductBuyBar(
        offer: offer,
        variant: variant,
        quantity: _quantity,
      ),
      body: Stack(
        children: [
          const CustomerBackdrop(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              ProductGalleryHeader(
                media: product.media,
                title: product.title,
                isLiked: _liked ?? product.isLiked,
                discountPercent: product.discountPercent,
                onToggleLike: () => _toggleLike(product),
                onShare: () => ShareService.product(
                  context: context,
                  productId: product.id,
                  title: product.title,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg,
                  DsSpacing.lg,
                  DsSpacing.lg,
                  DsSizes.bottomSafeGap,
                ),
                sliver: SliverList.list(
                  children: [
                    ProductHeadline(product: product),
                    DsGaps.vLg,
                    ProductPriceBlock(product: product, offer: offer),
                    if (product.hasMultipleOffers) ...[
                      DsGaps.section,
                      ProductOfferPicker(
                        offers: product.offers,
                        selected: offer,
                        onSelect: _selectOffer,
                      ),
                    ],
                    if ((offer?.variants.length ?? 0) > 1) ...[
                      DsGaps.section,
                      ProductVariantPicker(
                        variants: offer!.variants,
                        selected: variant,
                        onSelect: (v) => setState(() {
                          _variantId = v.id;
                          _quantity = 1;
                        }),
                      ),
                    ],
                    DsGaps.vLg,
                    ProductQuantityPicker(
                      quantity: _quantity.clamp(1, maxQuantity),
                      min: offer?.minOrderQty ?? 1,
                      max: maxQuantity,
                      onChanged: (q) => setState(() => _quantity = q),
                    ),
                    DsGaps.section,
                    ProductDetailBody(product: product),
                    DsGaps.section,
                    // Reem Intelligence. Above the closet panel because it is
                    // the broader statement — it can say "you already own one
                    // of these", which she should read before anything that
                    // encourages the purchase. Renders nothing at all when
                    // there is nothing to say, which is most products.
                    ProductIntelligenceNotes(productId: product.id),
                    DsGaps.section,
                    // Reem Closet. Placed above the seller card because it
                    // answers the question she is actually weighing — "بتنسّق
                    // مع شي عندي؟" — and it renders nothing when her closet is
                    // empty, so the page is unchanged for someone who has not
                    // built one.
                    ClosetPairingPanel(productId: product.id),
                    DsGaps.section,
                    // The boutique she is actually buying from — the offer
                    // picked above, not whichever one the catalogue lists
                    // first.
                    ProductSellerCard(product: product, offer: offer),
                    DsGaps.section,
                    ProductReviewsSection(productId: product.id),
                    DsGaps.section,
                    // Visually similar comes before the ordinary related rail:
                    // "شكلها متل هاي" is a stronger reason to look than "من
                    // نفس القسم". It renders nothing when the server has no
                    // visual neighbours, so the page is unchanged for a
                    // listing the indexer has not reached yet.
                    VisuallySimilarRail(productId: product.id),
                    DsGaps.section,
                    RelatedProductsRail(product: product),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// What the seller will actually ship: her stock, capped by any per-order
  /// limit she set.
  static int _maxQuantity(SellerOffer? offer, OfferVariant? variant) {
    final stock = variant?.stock ?? offer?.stock ?? 1;
    final cap = offer?.maxOrderQty;
    final limit = cap == null ? stock : (stock < cap ? stock : cap);
    return limit < 1 ? 1 : limit;
  }
}
