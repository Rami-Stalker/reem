import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_breakpoints.dart';

/// Spacing scale based on 4px grid (Material Design 3 compatible).
abstract final class DsSpacing {
  static const double unit = 4;

  static const double none = 0;
  static const double xxxs = unit / 2; // 2 — hairline gaps, icon nudges
  static const double xxs = unit; // 4
  static const double xs = unit * 2; // 8
  static const double sm = unit * 3; // 12
  static const double md = unit * 4; // 16
  static const double lg = unit * 5; // 20
  static const double xl = unit * 6; // 24
  static const double xxl = unit * 8; // 32
  static const double xxxl = unit * 10; // 40
  static const double huge = unit * 12; // 48
  static const double massive = unit * 16; // 64

  /// Gap between repeating items in lists / grids.
  static const double gutter = md; // 16
  /// Vertical rhythm between page sections.
  static const double sectionGap = xxl; // 32

  static const EdgeInsets paddingNone = EdgeInsets.zero;
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalMd =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg =
      EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);

  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: lg);

  /// Comfortable inner padding for cards and tiles.
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(lg);

  // ---------------------------------------------------------------------------
  // Component insets.
  //
  // Small paddings are where the grid used to break down: pills and badges
  // were padded 5/1, 6/2, 8/3, 10/4 and 12/6 across the app, which is why
  // two chips side by side never looked like the same component. Each shape
  // gets one inset, and components take it from here.
  // ---------------------------------------------------------------------------

  /// Count bubbles and status dots — the tightest shape in the system.
  static const EdgeInsets badgePadding =
      EdgeInsets.symmetric(horizontal: xs, vertical: xxxs);

  /// Inline status pills ("Delivered", "-20%").
  static const EdgeInsets pillPadding =
      EdgeInsets.symmetric(horizontal: sm, vertical: xxs);

  /// Tappable filter and choice chips.
  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: xs);

  /// A row in a list — settings, orders, addresses.
  static const EdgeInsets listRowPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: sm);

  /// Inner padding of a bottom sheet or dialog body.
  static const EdgeInsets sheetPadding =
      EdgeInsets.fromLTRB(lg, md, lg, xl);

  /// Gutter around a page section that already sits inside [screenHorizontal].
  static const EdgeInsets sectionPadding =
      EdgeInsets.symmetric(vertical: md);

  /// Clearance under scrollable content so it clears a floating bar or FAB.
  static const EdgeInsets bottomSafe = EdgeInsets.only(bottom: massive + xl);

  static double responsive(
    BuildContext context, {
    required double compact,
    required double medium,
    required double expanded,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= DsBreakpoints.expanded) return expanded;
    if (width >= DsBreakpoints.medium) return medium;
    return compact;
  }
}
