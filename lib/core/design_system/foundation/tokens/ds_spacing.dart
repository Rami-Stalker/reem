import 'package:flutter/material.dart';

import 'ds_breakpoints.dart';

/// Spacing scale based on 4px grid (Material Design 3 compatible).
abstract final class DsSpacing {
  static const double unit = 4;

  static const double none = 0;
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

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

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
