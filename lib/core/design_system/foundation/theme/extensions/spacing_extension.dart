import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

extension DsSpacingContext on BuildContext {
  double get spacingXs => DsSpacing.xs;
  double get spacingSm => DsSpacing.sm;
  double get spacingMd => DsSpacing.md;
  double get spacingLg => DsSpacing.lg;
  double get spacingXl => DsSpacing.xl;

  EdgeInsets get screenPadding => DsSpacing.screenPadding;

  double responsiveSpacing({
    required double compact,
    required double medium,
    required double expanded,
  }) =>
      DsSpacing.responsive(
        this,
        compact: compact,
        medium: medium,
        expanded: expanded,
      );
}
