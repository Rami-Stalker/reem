import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// The seller's visual identity: **the atelier**, the workroom behind the shop.
///
/// The seller surfaces used to be painted in a fixed slate-and-blue SaaS
/// palette. Two problems with that. It belonged to a different product — a
/// boutique owner opening Ohara went from blush and champagne to a stock
/// analytics dashboard — and every value was a `const Color`, so dark mode
/// painted white cards on an aubergine ground.
///
/// This palette fixes both. Structure comes from the brand's **plum**, money
/// and milestones from **champagne**, and every surface, ink and line resolves
/// from the live theme, so the command centre is legible in both modes. It
/// still reads as a workroom rather than a shop window: plum is sober where
/// the buyer's blush is warm, and the accents are reserved for data.
class SellerAtelierPalette {
  const SellerAtelierPalette({
    required this.ink,
    required this.muted,
    required this.background,
    required this.surface,
    required this.raised,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.gold,
    required this.goldSoft,
    required this.positive,
    required this.caution,
    required this.critical,
    required this.headerGradient,
    required this.goldGradient,
    required this.shadow,
    required this.series,
  });

  /// Primary text.
  final Color ink;

  /// Secondary text, axis labels, captions.
  final Color muted;

  /// The page ground.
  final Color background;

  /// Panels sitting on the ground.
  final Color surface;

  /// Panels that need to lift off another panel.
  final Color raised;

  /// Hairlines, dividers, chart grid.
  final Color line;

  /// The seller's structural accent — plum.
  final Color primary;
  final Color onPrimary;

  /// Plum at container strength, for tinted fills behind icons and chips.
  final Color primarySoft;

  /// Money, milestones, anything worth celebrating.
  final Color gold;
  final Color goldSoft;

  /// Trend and status semantics.
  final Color positive;
  final Color caution;
  final Color critical;

  /// The hero gradient — plum into aubergine, with a champagne edge.
  final LinearGradient headerGradient;
  final LinearGradient goldGradient;

  final List<BoxShadow> shadow;

  /// Ordered data-viz series, chosen so adjacent entries stay distinguishable
  /// in both themes and for the most common colour-vision deficiencies.
  final List<Color> series;

  /// Resolves the palette against the active theme.
  static SellerAtelierPalette of(BuildContext context) {
    final c = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SellerAtelierPalette(
      ink: c.onSurface,
      muted: c.onSurfaceVariant,
      background: c.background,
      surface: c.surface,
      raised: c.surfaceElevated,
      line: c.border,
      primary: isDark ? DsColors.mauve300 : DsColors.mauve600,
      onPrimary: isDark ? DsColors.mauve900 : DsColors.onMedia,
      primarySoft: isDark
          ? DsColors.mauve300.withValues(alpha: 0.18)
          : DsColors.mauve100,
      gold: isDark ? DsColors.gold300 : DsColors.gold500,
      goldSoft: isDark
          ? DsColors.gold300.withValues(alpha: 0.18)
          : DsColors.gold100,
      positive: c.success,
      caution: c.warning,
      critical: c.error,
      headerGradient: isDark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A2440), Color(0xFF2A1B32), Color(0xFF1F1726)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF75487E), Color(0xFF53355C), Color(0xFF3A2440)],
            ),
      goldGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE6C277), Color(0xFFC28E36)],
      ),
      shadow: [
        BoxShadow(
          color: c.shadow,
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
      series: [
        isDark ? DsColors.primary400 : DsColors.primary500,
        isDark ? DsColors.mauve300 : DsColors.mauve500,
        DsColors.gold400,
        isDark ? DsColors.accent400 : DsColors.accent500,
        DsColors.coral400,
      ],
    );
  }
}

extension SellerAtelierContext on BuildContext {
  /// The seller palette for the active theme.
  SellerAtelierPalette get atelier => SellerAtelierPalette.of(this);
}

/// The ground under every seller screen: the theme's background, ruled with a
/// faint plum grid — a cutting mat, not a spreadsheet.
class SellerAtelierBackground extends StatelessWidget {
  const SellerAtelierBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return ColoredBox(
      color: palette.background,
      child: CustomPaint(
        painter: _AtelierGridPainter(
          line: palette.primary.withValues(alpha: 0.06),
          bloom: palette.gold.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}

class _AtelierGridPainter extends CustomPainter {
  const _AtelierGridPainter({required this.line, required this.bloom});

  final Color line;
  final Color bloom;

  static const double _step = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // A single warm bloom in the top corner keeps the grid from reading as
    // graph paper.
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.08),
      size.width * 0.5,
      Paint()..color = bloom,
    );
  }

  @override
  bool shouldRepaint(_AtelierGridPainter old) =>
      old.line != line || old.bloom != bloom;
}
