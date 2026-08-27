import 'package:flutter/material.dart';

import '../foundation/theme/extensions/color_extension.dart';
import '../foundation/tokens/ds_colors.dart';

/// The administrator's visual identity: **the console**.
///
/// Three surfaces, three registers. The buyer gets blush, the seller gets the
/// atelier's plum, and the operator gets this — graphite and steel, because
/// the work here is oversight rather than commerce and the interface should
/// stay out of the way of the numbers.
///
/// The old `AdminExperience` was a wall of `const Color`s, which meant the
/// console painted white cards on a light-grey ground no matter what the
/// device asked for. Everything here resolves from the live theme instead, so
/// dark mode reaches the admin screens too.
///
/// Reem is still present, but held to the accents: plum for anything the
/// operator can act on, so a destructive control never reads as decoration.
class AdminConsolePalette {
  const AdminConsolePalette({
    required this.nav,
    required this.navMuted,
    required this.navSelected,
    required this.ink,
    required this.muted,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.positive,
    required this.caution,
    required this.critical,
    required this.info,
    required this.shadow,
    required this.series,
  });

  /// The navigation slab. Deep in both themes — console chrome reads as a
  /// frame around the work, not as another panel competing with it.
  final Color nav;
  final Color navMuted;
  final Color navSelected;

  final Color ink;
  final Color muted;
  final Color background;
  final Color surface;

  /// Table stripes, nested panels, anything that needs to sit half a step back.
  final Color surfaceAlt;
  final Color line;

  /// The action accent — brand plum, reserved for controls.
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;

  final Color positive;
  final Color caution;
  final Color critical;
  final Color info;

  final List<BoxShadow> shadow;

  /// Ordered data-viz series for the analytics charts.
  final List<Color> series;

  static AdminConsolePalette of(BuildContext context) {
    final c = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminConsolePalette(
      nav: isDark ? const Color(0xFF15101B) : const Color(0xFF1B1420),
      navMuted: const Color(0xFF9C8FA6),
      navSelected: Colors.white,
      ink: c.onSurface,
      muted: c.onSurfaceVariant,
      background: c.background,
      surface: c.surface,
      surfaceAlt: c.surfaceVariant,
      line: c.border,
      primary: isDark ? DsColors.mauve300 : DsColors.mauve600,
      onPrimary: isDark ? DsColors.mauve900 : Colors.white,
      primarySoft: isDark
          ? DsColors.mauve300.withValues(alpha: 0.18)
          : DsColors.mauve100,
      positive: c.success,
      caution: c.warning,
      critical: c.error,
      info: c.info,
      shadow: [
        BoxShadow(
          color: c.shadow,
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      series: [
        isDark ? DsColors.mauve300 : DsColors.mauve500,
        isDark ? DsColors.primary400 : DsColors.primary500,
        DsColors.gold400,
        isDark ? DsColors.accent400 : DsColors.accent500,
        DsColors.coral400,
      ],
    );
  }
}

extension AdminConsoleContext on BuildContext {
  /// The admin palette for the active theme.
  AdminConsolePalette get console => AdminConsolePalette.of(this);
}

/// The ground under every admin screen: the theme's background, ruled with
/// faint horizontal lines — a ledger page, not a dashboard wallpaper.
class AdminConsoleBackground extends StatelessWidget {
  const AdminConsoleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return ColoredBox(
      color: palette.background,
      child: CustomPaint(
        painter: _ConsoleRulePainter(
          line: palette.line.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _ConsoleRulePainter extends CustomPainter {
  const _ConsoleRulePainter({required this.line});

  final Color line;

  static const double _step = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (double y = _step; y < size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ConsoleRulePainter old) => old.line != line;
}
