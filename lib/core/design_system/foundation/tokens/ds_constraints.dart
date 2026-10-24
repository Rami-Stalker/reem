import 'package:ohara/core/design_system/foundation/tokens/ds_sizes.dart';

/// Layout constraint constants for content width and touch targets.
///
/// Kept as a named vocabulary for layout code; every value forwards to
/// [DsSizes] so there is exactly one number behind each concept.
abstract final class DsConstraints {
  /// Minimum touch target (WCAG / Material).
  static const double minTouchTarget = DsSizes.minTouchTarget;

  static const double minButtonHeight = DsSizes.minTouchTarget;
  static const double buttonHeightMd = DsSizes.controlLg;
  static const double buttonHeightLg = DsSizes.controlXl;

  static const double maxContentWidth = DsSizes.maxContentWidth;
  static const double maxFormWidth = DsSizes.maxFormWidth;
  static const double maxDialogWidth = DsSizes.maxDialogWidth;

  static const double appBarHeight = DsSizes.appBarHeight;
  static const double bottomBarHeight = DsSizes.bottomBarHeight;
  static const double fabSize = DsSizes.fabSize;

  static const double iconSm = DsSizes.iconSm;
  static const double iconMd = DsSizes.iconMd;
  static const double iconLg = DsSizes.iconLg;
}
