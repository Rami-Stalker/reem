import 'package:flutter/widgets.dart';

import 'package:reem/core/shared/entities/product.dart';

/// Where a product's interactions are drawn, on every shape that draws a
/// product.
///
/// ## Why this is a scope and not a parameter
///
/// The rule is *every product, everywhere, for ever* — the home page, a
/// department, search results, favourites, a boutique's shelf, an outfit, a
/// recommendation rail, and whatever surface is written next year. A
/// `onFavoriteToggle` parameter cannot express that: it makes the interaction
/// something each of the thirty call sites must remember to pass, and the
/// evidence that this does not work is the app as it was — the grid had a
/// heart, the mosaic had none, the rails had none, search had none, and the
/// one the grid did have wrote to a different store than the product page did.
///
/// So the affordance is *supplied once*, above the navigator, and every
/// product surface asks the scope for it. Adding a new grid tomorrow gets the
/// interactions by construction rather than by review.
///
/// ## Why the design system may hold it
///
/// This file names no provider and imports no state library. It declares a
/// slot and the shape of what fills it; `product_social` fills it with a live,
/// account-aware button, and `AppChrome` installs that once. The design system
/// stays presentational — it decides *where* the control sits on a card, which
/// is a layout decision, and nothing about what the control does.
///
/// With no scope installed — a widget preview, a golden test, a design-system
/// sandbox — [DsProductActions.of] returns null and cards draw exactly what
/// they drew before. Nothing here is required for a card to render.
typedef DsProductActionBuilder =
    Widget? Function(BuildContext context, Product product, DsProductSurface surface);

/// How much room the calling surface has, so one builder can answer them all.
///
/// Not a style flag — a size and density budget. A rail card is 152 points
/// wide with a price row that has overflowed before; a post card has a full
/// action bar. The same interaction has to be honest at both.
enum DsProductSurface {
  /// A catalogue tile: grid cell, mosaic pane, search result. Room for one
  /// control floating on the photograph.
  tile,

  /// A horizontal rail card — the tightest surface on the platform.
  rail,

  /// A full-bleed editorial card. Its own action bar handles the rest; this
  /// slot is unused there and the post card passes nothing.
  hero,
}

class DsProductActions extends InheritedWidget {
  const DsProductActions({
    super.key,
    required this.builder,
    required super.child,
  });

  final DsProductActionBuilder builder;

  /// The control for [product] on [surface], or null when no scope is
  /// installed above this widget.
  ///
  /// `getInheritedWidgetOfExactType` rather than `dependOn…`: the builder is
  /// installed once for the life of the app and never changes, so registering
  /// every product tile in the tree as a dependent would buy nothing and cost
  /// a rebuild list the length of the catalogue.
  static Widget? of(
    BuildContext context,
    Product product,
    DsProductSurface surface,
  ) {
    final scope = context
        .getInheritedWidgetOfExactType<DsProductActions>();
    if (scope == null || product.id.isEmpty) return null;
    return scope.builder(context, product, surface);
  }

  @override
  bool updateShouldNotify(DsProductActions oldWidget) =>
      builder != oldWidget.builder;
}
