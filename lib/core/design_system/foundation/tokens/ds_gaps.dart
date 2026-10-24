import 'package:flutter/widgets.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';

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
  static const Widget sliverBottomSafe = DsSliverBottomSafe();

  /// The box-layout twin, for a `Column` at the foot of a page.
  static const Widget bottomSafe = DsBottomSafe();
}

/// The gap at the foot of a scrolling page.
///
/// It used to be a flat 88 points, which was a guess at the height of the
/// floating bar — too much on a screen with no bar at all, and too little at
/// 160% text, where the bar's captions push it past a hundred. The shell now
/// reports the bar's real height as the page's bottom inset, so this reads it
/// rather than guessing, and adds a hand's width of air on top.
class DsSliverBottomSafe extends StatelessWidget {
  const DsSliverBottomSafe({super.key, this.extra = DsSpacing.lg});

  final double extra;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SizedBox(height: MediaQuery.paddingOf(context).bottom + extra),
  );
}

/// [DsSliverBottomSafe] for a box layout.
class DsBottomSafe extends StatelessWidget {
  const DsBottomSafe({super.key, this.extra = DsSpacing.lg});

  final double extra;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: MediaQuery.paddingOf(context).bottom + extra);
}
