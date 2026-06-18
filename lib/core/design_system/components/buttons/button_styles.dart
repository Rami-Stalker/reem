import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/theme/extensions/gradient_extension.dart';
import '../../foundation/theme/extensions/shadow_extension.dart';
import '../../foundation/tokens/ds_gradients.dart';

/// The visual intent of a button.
enum DsButtonVariant {
  /// Filled rose gradient — the single most important action on a screen.
  primary,

  /// Outlined rose — a strong but secondary action.
  secondary,

  /// Soft rose tint fill — calm secondary action, great in dense layouts.
  tonal,

  /// Champagne gold gradient — premium / occasion / upsell moments.
  accent,

  /// Transparent — tertiary / inline actions.
  ghost,

  /// Destructive action (delete, remove, cancel order).
  danger,
}

/// Resolved paint for a button variant in the current theme.
class DsButtonStyle {
  const DsButtonStyle({
    this.background,
    required this.foreground,
    this.gradient,
    this.border,
    this.shadow,
    this.overlay,
  });

  final Color? background;
  final Color foreground;
  final Gradient? gradient;
  final BorderSide? border;
  final List<BoxShadow>? shadow;

  /// Ripple / pressed overlay tint.
  final Color? overlay;

  static DsButtonStyle resolve(BuildContext context, DsButtonVariant variant) {
    final c = context.dsColors;
    switch (variant) {
      case DsButtonVariant.primary:
        return DsButtonStyle(
          gradient: context.primaryGradient,
          foreground: c.onPrimary,
          shadow: context.glowShadow(c.primary,
              blur: 22, alpha: context.ds.isDark ? 0.28 : 0.32),
          overlay: c.onPrimary.withValues(alpha: 0.12),
        );
      case DsButtonVariant.secondary:
        return DsButtonStyle(
          background: c.surface,
          foreground: c.primary,
          border: BorderSide(color: c.primary, width: 1.5),
          shadow: context.shadowXs,
          overlay: c.primary.withValues(alpha: 0.08),
        );
      case DsButtonVariant.tonal:
        return DsButtonStyle(
          background: c.primaryContainer,
          foreground: c.onPrimaryContainer,
          overlay: c.onPrimaryContainer.withValues(alpha: 0.08),
        );
      case DsButtonVariant.accent:
        return DsButtonStyle(
          gradient: DsGradients.champagne,
          foreground: c.onAccent,
          shadow: context.glowShadow(c.accent, blur: 20, alpha: 0.30),
          overlay: c.onAccent.withValues(alpha: 0.10),
        );
      case DsButtonVariant.ghost:
        return DsButtonStyle(
          background: Colors.transparent,
          foreground: c.primary,
          overlay: c.primary.withValues(alpha: 0.10),
        );
      case DsButtonVariant.danger:
        return DsButtonStyle(
          background: c.error,
          foreground: c.onError,
          shadow: context.glowShadow(c.error, blur: 18, alpha: 0.26),
          overlay: c.onError.withValues(alpha: 0.12),
        );
    }
  }

  // ---- Backwards-compatible named constructors (kept for existing call sites).
  static DsButtonStyle primary(BuildContext context, [Object? _]) =>
      resolve(context, DsButtonVariant.primary);

  static DsButtonStyle secondary(BuildContext context, [Object? _]) =>
      resolve(context, DsButtonVariant.secondary);

  static DsButtonStyle ghost(BuildContext context) =>
      resolve(context, DsButtonVariant.ghost);
}
