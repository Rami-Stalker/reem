import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// High-contrast color adjustments for accessibility modes.
abstract final class DsContrastProfiles {
  static ColorScheme highContrastLight(ColorScheme base) => base.copyWith(
        primary: DsColors.primary800,
        onPrimary: Colors.white,
        onSurface: Colors.black,
        outline: Colors.black,
      );

  static ColorScheme highContrastDark(ColorScheme base) => base.copyWith(
        primary: DsColors.primary200,
        onPrimary: Colors.black,
        onSurface: Colors.white,
        outline: Colors.white,
      );
}
