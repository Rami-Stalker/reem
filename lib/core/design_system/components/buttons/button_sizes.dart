import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';

enum DsButtonSize { sm, md, lg }

extension DsButtonSizeValues on DsButtonSize {
  double get height => switch (this) {
        DsButtonSize.sm => DsConstraints.minButtonHeight,
        DsButtonSize.md => DsConstraints.buttonHeightMd,
        DsButtonSize.lg => DsConstraints.buttonHeightLg,
      };

  EdgeInsets get padding => switch (this) {
        DsButtonSize.sm =>
          const EdgeInsets.symmetric(horizontal: DsSpacing.md, vertical: DsSpacing.xs),
        DsButtonSize.md =>
          const EdgeInsets.symmetric(horizontal: DsSpacing.xl, vertical: DsSpacing.sm),
        DsButtonSize.lg =>
          const EdgeInsets.symmetric(horizontal: DsSpacing.xxl, vertical: DsSpacing.md),
      };

  double get fontSize => switch (this) {
        DsButtonSize.sm => 13,
        DsButtonSize.md => 15,
        DsButtonSize.lg => 16,
      };

  double get iconSize => switch (this) {
        DsButtonSize.sm => DsConstraints.iconSm,
        DsButtonSize.md => 22,
        DsButtonSize.lg => DsConstraints.iconMd,
      };

  BorderRadius get borderRadius => switch (this) {
        DsButtonSize.sm => DsRadius.borderMd,
        DsButtonSize.md => DsRadius.borderXl,
        DsButtonSize.lg => DsRadius.borderXxl,
      };
}
