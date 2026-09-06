import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_gaps.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/patterns/admin_console.dart';
import 'package:reem/core/design_system/patterns/customer_boutique.dart';
import 'package:reem/core/design_system/patterns/seller_atelier.dart';

/// Brand blends that are the same in both themes.
///
/// Everything that used to live here as a fixed swatch -- `ink`, `muted`,
/// `pearl`, `ivory` and the rest -- moved to [CustomerBoutiquePalette], where
/// it resolves against the live theme like the seller's and the operator's
/// palettes always did. What is left is the handful of values that genuinely
/// do not change with the mode.
abstract final class CustomerExperience {
  /// Rose into champagne. Reads on both grounds, which is why it survived the
  /// move as a constant; prefer `context.boutique.signatureGradient` in new
  /// code so a future dark variant reaches every caller.
  static const LinearGradient signatureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF6C9B), Color(0xFFC84778), Color(0xFFEACB8D)],
    stops: [0, .58, 1],
  );

  /// The light-mode silk wash. Kept for the two painters that need it as a
  /// compile-time constant; page grounds should use [CustomerBackdrop].
  static const LinearGradient silkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFBFD), Color(0xFFFFEEF5), Color(0xFFFFF8EA)],
    stops: [0, .48, 1],
  );
}

// The seller's palette is `SellerAtelierPalette` (`context.atelier`), the
// operator's is `AdminConsolePalette` (`context.console`), and the buyer's is
// `CustomerBoutiquePalette` (`context.boutique`). All three resolve from the
// live theme; none of them are constants any more.

/// The page ground under every buyer screen: a soft silk wash crossed by two
/// ribbons.
///
/// It resolves against the active theme. In light mode it is the pearl-to-
/// champagne silk; in dark it becomes deep aubergine with a dim plum bloom, so
/// dark mode actually reaches the buyer surfaces instead of being painted over
/// by a fixed pink gradient.
class CustomerBackdrop extends StatelessWidget {
  const CustomerBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.boutique.groundGradient),
      child: CustomPaint(
        painter: _SilkBackdropPainter(
          wash: isDark
              ? colors.primary.withValues(alpha: 0.10)
              : const Color(0x22E95C8F),
          ribbonWarm: isDark
              ? colors.accent.withValues(alpha: 0.10)
              : const Color(0x33EACB8D),
          ribbonRose: isDark
              ? colors.primary.withValues(alpha: 0.14)
              : const Color(0x26C6386F),
        ),
      ),
    );
  }
}

/// Kept as the name older admin screens import; the console background is the
/// implementation.
class AdminChromeBackground extends StatelessWidget {
  const AdminChromeBackground({super.key});

  @override
  Widget build(BuildContext context) => const AdminConsoleBackground();
}

class CustomerPanel extends StatelessWidget {
  const CustomerPanel({
    super.key,
    required this.child,
    this.padding = DsSpacing.paddingLg,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    // Reads from the theme rather than a fixed white glass, so the panel is a
    // raised surface in light mode and a lifted aubergine one in dark. The
    // former `BackdropFilter` blurred a flat page background — pure GPU cost
    // for no visible effect — and is gone; blur belongs on panels that sit
    // over imagery, not over the page.
    final panel = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DsRadius.borderCard,
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

class CustomerPrimaryButton extends StatelessWidget {
  const CustomerPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: palette.signatureGradient,
        borderRadius: DsRadius.borderFull,
        boxShadow: palette.shadow,
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: DsSizes.iconXs,
                height: DsSizes.iconXs,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DsColors.onMedia,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: DsSizes.iconXs),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          // The ground here is the rose-to-champagne signature in both
          // themes, so the label stays white rather than following the
          // scheme onPrimary, which inverts in dark mode.
          foregroundColor: DsColors.onMedia,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(DsSizes.controlLg),
          shape: const StadiumBorder(),
          textStyle: context.dsText.button,
        ),
      ),
    );
  }
}

class CustomerSectionTitle extends StatelessWidget {
  const CustomerSectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    return Padding(
      padding: DsSpacing.screenHorizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: text.overline.tint(context.boutique.primary),
                  ),
                  DsGaps.vXxs,
                ],
                Text(title, style: text.screenTitle),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SellerPanel extends StatelessWidget {
  const SellerPanel({
    super.key,
    required this.child,
    this.padding = DsSpacing.paddingMd,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: palette.line),
        boxShadow: palette.shadow,
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DsRadius.borderLg,
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

class SellerStatusPill extends StatelessWidget {
  const SellerStatusPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;

  /// Defaults to the atelier's plum. Nullable rather than a `const` default
  /// because the palette is resolved from the theme, not a fixed swatch.
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.atelier.primary;
    return Container(
      padding: DsSpacing.pillPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: DsSizes.iconXxs, color: color),
            DsGaps.hXxs,
          ],
          Text(label, style: context.dsText.badge.tint(color)),
        ],
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    required this.child,
    this.padding = DsSpacing.paddingLg,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: palette.line),
        boxShadow: palette.shadow,
      ),
      child: child,
    );
  }
}

class AdminMetricPill extends StatelessWidget {
  const AdminMetricPill({
    super.key,
    required this.label,
    this.color,
  });

  final String label;

  /// Null means the console's action accent — a default argument cannot read
  /// the theme.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.console.primary;
    return Container(
      padding: DsSpacing.pillPadding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .08),
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: tint.withValues(alpha: .18)),
      ),
      child: Text(label, style: context.dsText.badge.tint(tint)),
    );
  }
}

class _SilkBackdropPainter extends CustomPainter {
  const _SilkBackdropPainter({
    required this.wash,
    required this.ribbonWarm,
    required this.ribbonRose,
  });

  /// Corner wash, and the two ribbon strokes. Passed in so the same geometry
  /// serves both themes.
  final Color wash;
  final Color ribbonWarm;
  final Color ribbonRose;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final roseWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [wash, wash.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawRect(rect, roseWash);

    final champagne = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..color = ribbonWarm;
    final rose = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = ribbonRose;

    final pathA = Path()
      ..moveTo(size.width * -.1, size.height * .18)
      ..cubicTo(
        size.width * .26,
        size.height * .06,
        size.width * .42,
        size.height * .46,
        size.width * .82,
        size.height * .32,
      )
      ..cubicTo(
        size.width * 1.02,
        size.height * .25,
        size.width * 1.06,
        size.height * .42,
        size.width * 1.16,
        size.height * .38,
      );

    final pathB = Path()
      ..moveTo(size.width * -.2, size.height * .72)
      ..cubicTo(
        size.width * .16,
        size.height * .52,
        size.width * .42,
        size.height * .78,
        size.width * .68,
        size.height * .6,
      )
      ..cubicTo(
        size.width * .9,
        size.height * .44,
        size.width * 1.06,
        size.height * .54,
        size.width * 1.22,
        size.height * .44,
      );

    canvas.drawPath(pathA, champagne);
    canvas.drawPath(pathB, rose);
  }

  @override
  bool shouldRepaint(covariant _SilkBackdropPainter oldDelegate) =>
      oldDelegate.wash != wash ||
      oldDelegate.ribbonWarm != ribbonWarm ||
      oldDelegate.ribbonRose != ribbonRose;
}

