import 'package:flutter/material.dart';

extension DsTypographyContext on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  TextStyle? get displayLarge => textTheme.displayLarge;
  TextStyle? get headlineMedium => textTheme.headlineMedium;
  TextStyle? get titleLarge => textTheme.titleLarge;
  TextStyle? get bodyMedium => textTheme.bodyMedium;
  TextStyle? get labelMedium => textTheme.labelMedium;
}
