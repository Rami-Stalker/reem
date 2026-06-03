import 'package:flutter/material.dart';

/// High-contrast color adjustments for accessibility modes.
abstract final class DsContrastProfiles {
  static ColorScheme highContrastLight(ColorScheme base) => base.copyWith(
        primary: const Color(0xFF9E2A4A),
        onPrimary: Colors.white,
        onSurface: Colors.black,
        outline: Colors.black,
      );

  static ColorScheme highContrastDark(ColorScheme base) => base.copyWith(
        primary: const Color(0xFFFFB4C8),
        onPrimary: Colors.black,
        onSurface: Colors.white,
        outline: Colors.white,
      );
}
