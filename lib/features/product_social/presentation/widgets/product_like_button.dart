import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/product_social/presentation/product_gestures.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';

/// The heart a product wears wherever it is not told as a post.
///
/// This is the whole of the "outside the product page" half of the rule: on a
/// grid tile, a mosaic pane, a rail card or a search result, the one thing she
/// can do without opening the piece is **like** it. Share, save, «أضيفي إلى
/// صفحتي» and the thread are one tap away on the product page, where there is
/// room to label them.
///
/// ## It is a like, not a favourite
///
/// The heart on a catalogue tile used to toggle «المفضّلة» — her private shelf
/// — through `favoritesNotifierProvider`, which is a *different store* from
/// the one the product page and the post card write to. So a piece she
/// favourited from the home grid opened with an empty heart, and a piece she
/// liked on its page came back to the grid looking untouched. Two hearts
/// meaning two things in two stores, on one product.
///
/// Now the tile's heart is the same public like the post card's is, reading
/// and writing the one shelf in [productEngagementProvider]. Saving is a
/// deliberate act and lives where it can be named.
///
/// ## It seeds
///
/// Every surface that draws a product draws this, and this seeds the shared
/// store — so "the counts and her own state arrive" is not something each
/// screen has to remember. [ProductEngagementNotifier.seed] gathers a frame's
/// worth of cards and asks for them in one request, which is why a grid of
/// forty tiles costs one round trip rather than forty.
class ProductLikeButton extends ConsumerStatefulWidget {
  const ProductLikeButton({
    super.key,
    required Product this.product,
    this.compact = false,
    this.showCount = true,
    this.onChanged,
  }) : productId = null;

  /// For a surface that holds a product's id and not the product — a bundle's
  /// piece, a drop's item, a closet suggestion. Identical behaviour; the
  /// tallies are simply blank until the batch read answers, because there is
  /// no served row to paint from in the meantime.
  const ProductLikeButton.forId(
    String this.productId, {
    super.key,
    this.compact = false,
    this.showCount = true,
    this.onChanged,
  }) : product = null;

  final Product? product;
  final String? productId;

  String get id => product?.id ?? productId!;

  /// The rail's budget: a smaller target and no count. A 152-point card has
  /// had a row overflow in it before.
  final bool compact;

  /// Off for surfaces where a number beside the heart would crowd the
  /// photograph.
  final bool showCount;

  /// Told what the like became, after the store has applied it.
  ///
  /// For the surfaces where a like is *also* a signal to something else — a
  /// visual-search match, where it is the feedback that teaches the ranker.
  /// The alternative was a second heart on the same card meaning a second
  /// thing, which is how a shopper learns to trust neither.
  final void Function(bool liked)? onChanged;

  @override
  ConsumerState<ProductLikeButton> createState() => _ProductLikeButtonState();
}

class _ProductLikeButtonState extends ConsumerState<ProductLikeButton> {
  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(ProductLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _seed();
  }

  /// After the frame: a provider may not be written while the tree that
  /// watches it is being built, and a grid builds these by the dozen.
  void _seed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = ref.read(productEngagementProvider.notifier);
      final product = widget.product;
      if (product != null) {
        store.seed([product]);
      } else {
        store.seedIds([widget.id]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final product = widget.product;
    final engagement = product != null
        ? ProductGestures.watch(ref, product)
        : ProductGestures.watchId(ref, widget.id);
    final liked = engagement.isLiked;
    final size = widget.compact ? 28.0 : 32.0;

    // Only once the server has answered. Before that the count is whatever the
    // catalogue row carried, which is right, but printing a "0" beside an
    // unfilled heart on every tile of a fresh grid reads as "nobody likes
    // anything here".
    final count = widget.showCount && engagement.likes > 0
        ? formatCount(engagement.likes)
        : null;

    return Semantics(
      button: true,
      selected: liked,
      label: context.l10n.a11yLike,
      child: GestureDetector(
        onTap: () async {
          final wanted = !liked;
          await ProductGestures.likeById(context, ref, widget.id);
          if (!mounted) return;
          // Read back rather than assume: the gesture refuses for a guest and
          // reverts on a failed write, and a listener told "liked" for a tap
          // that did not take would be teaching a ranker a fact that is not
          // true.
          final settled = ProductGestures.watchId(ref, widget.id).isLiked;
          if (settled == wanted) widget.onChanged?.call(settled);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: size,
          constraints: BoxConstraints(minWidth: size),
          padding: count == null
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
          decoration: BoxDecoration(
            color: c.glass,
            borderRadius: DsRadius.borderPill,
            border: Border.all(color: c.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The fill is the feedback. It changes the moment she taps —
              // the store is optimistic — and reverts only if the write is
              // refused, which is the one case where the heart was a lie.
              AnimatedSwitcher(
                duration: DsMotion.fast,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(liked),
                  size: widget.compact ? 15 : 17,
                  color: liked ? c.favorite : c.onSurface,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: DsSpacing.xxxs),
                Text(
                  count,
                  style: context.dsText.micro.semibold.tint(c.onSurface),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
