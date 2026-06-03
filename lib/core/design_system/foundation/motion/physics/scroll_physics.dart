import 'package:flutter/material.dart';

/// Scroll physics presets.
abstract final class DsScrollPhysics {
  static const ScrollPhysics standard = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  static const ScrollPhysics clamping = ClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  static const ScrollPhysics never = NeverScrollableScrollPhysics();
}
