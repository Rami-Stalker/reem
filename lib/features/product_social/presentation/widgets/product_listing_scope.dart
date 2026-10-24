import 'package:flutter/widgets.dart';

import 'package:reem/core/shared/entities/product.dart';

/// One line a listing adds to a product's «…» menu — the action that only
/// makes sense where she is reading it.
///
/// «إزالة من المختارة لكِ» means something under «مختارة لكِ» and nothing on
/// a department page, so it cannot live in the menu itself. The listing that
/// owns the meaning installs it above its cards, and every product card under
/// it — in any shape — offers it.
class ProductListingAction {
  const ProductListingAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Future<void> Function(Product product) onSelected;
}

class ProductListingScope extends InheritedWidget {
  const ProductListingScope({
    super.key,
    required this.action,
    required super.child,
  });

  final ProductListingAction action;

  /// Read when the menu opens, not while building, so no dependency is kept.
  static ProductListingAction? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProductListingScope>()?.action;

  @override
  bool updateShouldNotify(ProductListingScope oldWidget) =>
      action != oldWidget.action;
}
