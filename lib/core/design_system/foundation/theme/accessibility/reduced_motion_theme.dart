import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Respects platform reduced-motion settings for animations.
abstract final class DsReducedMotion {
  static bool get isEnabled =>
      SchedulerBinding.instance.platformDispatcher.accessibilityFeatures
          .disableAnimations;

  static Duration duration(Duration preferred) =>
      isEnabled ? Duration.zero : preferred;

  static Curve curve(Curve preferred) => isEnabled ? Curves.linear : preferred;
}
