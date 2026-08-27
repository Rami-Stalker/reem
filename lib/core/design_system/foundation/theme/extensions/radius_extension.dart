import 'package:flutter/material.dart';

export 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';

extension DsRadiusExtension on double {
  BorderRadius get asBorderRadius => BorderRadius.circular(this);
}
