import 'package:flutter/material.dart';

import '../foundation/theme/extensions/color_extension.dart';
import '../foundation/tokens/ds_radius.dart';
import '../foundation/tokens/ds_spacing.dart';
import '../foundation/tokens/ds_typography.dart';
import 'admin_console.dart';
import 'seller_atelier.dart';

abstract final class CustomerExperience {
  static const Color ink = Color(0xFF21161C);
  static const Color muted = Color(0xFF7A6470);
  static const Color blush = Color(0xFFE95C8F);
  static const Color rose = Color(0xFFC6386F);
  static const Color plum = Color(0xFF533447);
  static const Color champagne = Color(0xFFEACB8D);
  static const Color pearl = Color(0xFFFFFAFC);
  static const Color ivory = Color(0xFFFFF6F0);
  static const Color sage = Color(0xFF5D977B);

  static const LinearGradient silkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFBFD), Color(0xFFFFEEF5), Color(0xFFFFF8EA)],
    stops: [0, .48, 1],
  );

  static const LinearGradient signatureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF6C9B), Color(0xFFC84778), Color(0xFFEACB8D)],
    stops: [0, .58, 1],
  );

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x1FC6386F),
      blurRadius: 30,
      offset: Offset(0, 18),
    ),
    BoxShadow(
      color: Color(0x12EACB8D),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}

// The seller's palette used to live here as a fixed slate-and-blue set. It is
// now `SellerAtelierPalette` in `patterns/seller_atelier.dart`, resolved from
// the live theme — the old constants could not survive dark mode and did not
// belong to Reem.

abstract final class AdminExperience {
  static const Color nav = Color(0xFF0B1220);
  static const Color navMuted = Color(0xFF94A3B8);
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8FAFC);
  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF64748B);
  static const Color line = Color(0xFFD8DEE8);
  static const Color primary = Color(0xFF3156D4);
  static const Color success = Color(0xFF047857);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFB91C1C);

  static const List<BoxShadow> shadow = [
    BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}

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

    final gradient = isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.background,
              colors.surfaceDim,
              colors.background,
            ],
            stops: const [0, .52, 1],
          )
        : CustomerExperience.silkGradient;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
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
    this.padding = const EdgeInsets.all(20),
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
        borderRadius: DsRadius.borderXxxl,
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
        borderRadius: DsRadius.borderXxxl,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: CustomerExperience.signatureGradient,
        borderRadius: DsRadius.borderFull,
        boxShadow: CustomerExperience.softShadow,
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontWeight: DsTypography.bold,
            fontSize: DsTypography.labelLarge,
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
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
                    style: const TextStyle(
                      color: CustomerExperience.rose,
                      fontSize: DsTypography.labelMedium,
                      fontWeight: DsTypography.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: CustomerExperience.ink,
                    fontFamily: DsTypography.fontFamilyDisplay,
                    fontFamilyFallback: DsTypography.displayFallback,
                    fontSize: DsTypography.headlineSmall,
                    fontWeight: DsTypography.bold,
                    height: 1.14,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SellerPanel extends StatelessWidget {
  const SellerPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .08),
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: tint.withValues(alpha: .18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: DsTypography.labelSmall,
          fontWeight: DsTypography.bold,
        ),
      ),
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

