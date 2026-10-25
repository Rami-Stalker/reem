
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/product_variant.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_pairing_panel.dart';
import 'package:ohara/features/intelligence/presentation/widgets/product_intelligence_notes.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_buy_bar.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_detail_body.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_fit_line.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_gallery_header.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_headline.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_option_pickers.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_price_block.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_reviews_section.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_seller_card.dart';
import 'package:ohara/features/product_details/presentation/widgets/related_products_rail.dart';
import 'package:ohara/features/product_social/presentation/product_gestures.dart';
import 'package:ohara/features/product_social/presentation/widgets/product_social_bar.dart';
import 'package:ohara/features/visual_search/presentation/widgets/visually_similar_rail.dart';

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
        appBar: OharaAppBar(title: context.l10n.error),
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
        product: product,
        offer: offer,
        variant: variant,
        quantity: _quantity,
      ),
      body: Stack(
        children: [
          const CustomerBackdrop(),
          CustomScrollView(
            slivers: [
              ProductGalleryHeader(
                media: product.media,
                title: product.title,
                // «المفضّلة», read from the same store as the bookmark in the
                // action bar below, so the two can never disagree — and drawn
                // as a bookmark rather than a heart, because the heart on every
                // catalogue tile is now the product's public like.
                isSaved: ProductGestures.watch(ref, product).isSaved,
                discountPercent: product.discountPercent,
                onToggleSave: () => ProductGestures(context, ref, product).save(),
                // Through the gestures, so a share from the header is counted
                // the same way as one from the action bar.
                onShare: () => ProductGestures(context, ref, product).share(),
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
                    DsGaps.vMd,
                    // The heart, the thread, the share, «أضيفي إلى صفحتي» and
                    // the bookmark — everything a post has, on every product.
                    ProductSocialBar(product: product),
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
                    // ── The fitting room ─────────────────────────────────
                    //
                    // Everything that answers "is this right for *me*" sits
                    // together, straight under the size she is choosing and
                    // above the long description: whether her size is kept,
                    // what Ohara knows about the piece for her, and how it goes
                    // with what she owns. Each renders nothing when it has
                    // nothing to say, so a piece nobody has bought, for a
                    // shopper with no closet, reads exactly as it did.
                    //
                    // The gaps collapse with their sections, so a page with
                    // nothing to say here gains no blank band under the sizes.
                    ProductFitLine(productId: product.id, variant: variant),
                    // Ohara Intelligence. Above the closet panel because it is
                    // the broader statement — it can say "you already own one
                    // of these", which she should read before anything that
                    // encourages the purchase.
                    DsCollapsingGap(
                      before: DsSpacing.sectionGap,
                      child: ProductIntelligenceNotes(productId: product.id),
                    ),
                    // Ohara Closet — "بتنسّق مع شي عندي؟".
                    DsCollapsingGap(
                      before: DsSpacing.sectionGap,
                      child: ClosetPairingPanel(productId: product.id),
                    ),
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
