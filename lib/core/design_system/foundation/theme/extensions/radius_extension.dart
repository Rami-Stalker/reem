import 'package:flutter/material.dart';

export '../../tokens/ds_radius.dart';

extension DsRadiusExtension on double {
  BorderRadius get asBorderRadius => BorderRadius.circular(this);
}
