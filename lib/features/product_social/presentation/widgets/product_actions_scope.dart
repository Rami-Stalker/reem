import 'package:flutter/widgets.dart';

import 'package:reem/core/design_system/patterns/product_actions.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/product_social/presentation/widgets/product_like_button.dart';

/// Installs the product interactions, once, for the whole app.
///
/// Mounted in `AppChrome` — above the navigator, below the theme — so it
/// covers every route including pushed pages, sheets and dialogs. From then on
/// any surface that draws a product draws its interactions, whether or not
/// whoever wrote that surface knew this existed.
///
/// That is the point. The rule is "every product, everywhere": the home
/// showcase, a department, search, favourites, a boutique's shelf, an outfit,
/// a recommendation rail, a bundle, a visual-search match — and the surface
/// somebody adds next month. Per-screen wiring is how the app arrived at a
/// grid with a heart, a mosaic with none, four rails with none, and search
/// with none.
class ProductActionsScope extends StatelessWidget {
  const ProductActionsScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DsProductActions(builder: _action, child: child);
  }

  /// What each surface gets.
  ///
  /// A tile and a rail card both get the like — the one interaction that is
  /// honest at a glance and needs no label. A hero is a post card, which draws
  /// the full action bar itself and passes nothing here.
  static Widget? _action(
    BuildContext context,
    Product product,
    DsProductSurface surface,
  ) {
    return switch (surface) {
      DsProductSurface.tile => ProductLikeButton(
        key: ValueKey('like-${product.id}'),
        product: product,
      ),
      DsProductSurface.rail => ProductLikeButton(
        key: ValueKey('like-${product.id}'),
        product: product,
        compact: true,
        // A 152-point card carries a price, a rating and sometimes a scarcity
        // badge already. The number goes; the heart stays.
        showCount: false,
      ),
      DsProductSurface.hero => null,
    };
  }
}
