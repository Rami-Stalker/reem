import 'package:flutter/widgets.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// Const spacer widgets on the 4px grid.
///
/// `SizedBox(height: 12)` appeared roughly two hundred times across the app,
/// with 2, 3, 5, 6, 9 and 10 all showing up alongside the grid values — the
/// vertical rhythm of a screen was whatever its author typed that afternoon.
/// These are the same numbers as [DsSpacing], pre-wrapped so the grid is the
/// path of least resistance.
///
/// `v*` separates rows in a [Column]; `h*` separates items in a [Row].
abstract final class DsGaps {
  // Vertical -----------------------------------------------------------------
  static const Widget vXxxs = SizedBox(height: DsSpacing.xxxs); // 2
  static const Widget vXxs = SizedBox(height: DsSpacing.xxs); // 4
  static const Widget vXs = SizedBox(height: DsSpacing.xs); // 8
  static const Widget vSm = SizedBox(height: DsSpacing.sm); // 12
  static const Widget vMd = SizedBox(height: DsSpacing.md); // 16
  static const Widget vLg = SizedBox(height: DsSpacing.lg); // 20
  static const Widget vXl = SizedBox(height: DsSpacing.xl); // 24
  static const Widget vXxl = SizedBox(height: DsSpacing.xxl); // 32
  static const Widget vXxxl = SizedBox(height: DsSpacing.xxxl); // 40
  static const Widget vHuge = SizedBox(height: DsSpacing.huge); // 48

  /// Vertical rhythm between page sections.
  static const Widget section = SizedBox(height: DsSpacing.sectionGap);

  // Horizontal ---------------------------------------------------------------
  static const Widget hXxxs = SizedBox(width: DsSpacing.xxxs); // 2
  static const Widget hXxs = SizedBox(width: DsSpacing.xxs); // 4
  static const Widget hXs = SizedBox(width: DsSpacing.xs); // 8
  static const Widget hSm = SizedBox(width: DsSpacing.sm); // 12
  static const Widget hMd = SizedBox(width: DsSpacing.md); // 16
  static const Widget hLg = SizedBox(width: DsSpacing.lg); // 20
  static const Widget hXl = SizedBox(width: DsSpacing.xl); // 24
  static const Widget hXxl = SizedBox(width: DsSpacing.xxl); // 32

  /// Nothing at all — for conditional-gap expressions that must stay const.
  static const Widget none = SizedBox.shrink();

  // Sliver equivalents, for the `CustomScrollView` pages the app is built on.
  static const Widget sliverXs = SliverToBoxAdapter(child: vXs);
  static const Widget sliverSm = SliverToBoxAdapter(child: vSm);
  static const Widget sliverMd = SliverToBoxAdapter(child: vMd);
  static const Widget sliverLg = SliverToBoxAdapter(child: vLg);
  static const Widget sliverXl = SliverToBoxAdapter(child: vXl);
  static const Widget sliverXxl = SliverToBoxAdapter(child: vXxl);
  static const Widget sliverSection = SliverToBoxAdapter(child: section);

  /// Bottom breathing room so content clears a floating bar or FAB.
  static const Widget sliverBottomSafe = SliverToBoxAdapter(child: bottomSafe);

  /// The same room as a box, for the end of a `SliverList.list` or `Column`.
  ///
  /// A sliver in a list of boxes does not lay out — it takes the whole page
  /// down with it. That is what blanked the content studio and the composer.
  static const Widget bottomSafe =
      SizedBox(height: DsSpacing.massive + DsSpacing.xl);
}
