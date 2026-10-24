import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// Border width and style tokens.
abstract final class DsBorders {
  static const double widthNone = 0;
  static const double widthHairline = 0.5;
  static const double widthThin = 1;
  static const double widthMedium = 1.5;
  static const double widthThick = 2;

  static BorderSide hairline([Color? color]) => BorderSide(
        color: color ?? DsColors.neutral200,
        width: widthHairline,
      );

  static BorderSide thin([Color? color]) => BorderSide(
        color: color ?? DsColors.neutral200,
        width: widthThin,
      );

  static BorderSide medium([Color? color]) => BorderSide(
        color: color ?? DsColors.primary200,
        width: widthMedium,
      );

  static BorderSide focused(Color color) => BorderSide(
        color: color,
        width: widthThick,
      );
}
