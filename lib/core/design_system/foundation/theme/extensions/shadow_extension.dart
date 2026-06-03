import 'package:flutter/material.dart';

import 'color_extension.dart';

extension DsShadowContext on BuildContext {
  List<BoxShadow> get luxuryShadow => ds.luxuryShadow;
  List<BoxShadow> get softShadow => ds.softShadow;
}
