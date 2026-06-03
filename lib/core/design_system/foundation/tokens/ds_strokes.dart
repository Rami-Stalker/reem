import 'package:flutter/material.dart';

/// Stroke widths for icons, dividers, and outlines.
abstract final class DsStrokes {
  static const double hairline = 0.5;
  static const double thin = 1;
  static const double regular = 1.5;
  static const double medium = 2;
  static const double thick = 3;

  static const StrokeCap capRound = StrokeCap.round;
  static const StrokeJoin joinRound = StrokeJoin.round;
}
