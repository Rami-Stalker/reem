import 'package:flutter/material.dart';

/// Responsive breakpoint definitions (Material Design 3 window size classes).
abstract final class DsBreakpoints {
  static const double compact = 0;
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < medium;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= medium && w < expanded;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;

  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= large;

  static DsWindowSize windowSizeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= large) return DsWindowSize.large;
    if (width >= expanded) return DsWindowSize.expanded;
    if (width >= medium) return DsWindowSize.medium;
    return DsWindowSize.compact;
  }
}

enum DsWindowSize { compact, medium, expanded, large }
