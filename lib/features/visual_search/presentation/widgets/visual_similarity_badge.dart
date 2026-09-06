import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';

/// "٩٤٪ مشابه".
///
/// The one number this whole feature is judged on, so the badge is built to be
/// read at a glance and to be honest at a second glance:
///
///  - The **band** — strong, good, loose — is a colour, not a word, because
///    the difference between 94% and 89% matters far less than the difference
///    between "this is the dress" and "this is in the right area", and a
///    gradient of eleven shades would imply a precision the number does not
///    have.
///  - A **loose** match is drawn in a muted tone rather than in the brand's
///    rose. Dressing up a 40% as if it were a find is exactly the small lie
///    that makes a shopper stop believing the badge.
class VisualSimilarityBadge extends StatelessWidget {
  const VisualSimilarityBadge({
    super.key,
    required this.percent,
    this.compact = false,
  });

  /// 0–100, rounded by the server so every surface shows the same figure.
  final int percent;

  /// Sits over a photograph rather than beside a title.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final band = _Band.of(percent);

    final foreground = switch (band) {
      _Band.strong => colors.onPrimary,
      _Band.good => colors.onSecondaryContainer,
      _Band.loose => colors.onSurfaceVariant,
    };
    final background = switch (band) {
      _Band.strong => colors.primary,
      _Band.good => colors.secondaryContainer,
      _Band.loose => colors.surfaceVariant,
    };

    return Semantics(
      label: 'نسبة التشابه $percent بالمئة',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? DsSpacing.xs : DsSpacing.sm,
          vertical: compact ? DsSpacing.xxs : DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(DsRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              band == _Band.strong
                  ? Icons.auto_awesome_rounded
                  : Icons.compare_arrows_rounded,
              size: compact ? 12 : 14,
              color: foreground,
            ),
            const SizedBox(width: DsSpacing.xxs),
            Text(
              '$percent٪ مشابه',
              style: (compact
                      ? context.dsText.caption
                      : context.dsText.label)
                  .copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Band {
  strong,
  good,
  loose;

  /// The two thresholds, in one place.
  ///
  /// 85 is where two photographs are of the same garment or of two that would
  /// be mistaken for each other on a rail; 65 is where "the same sort of
  /// thing" ends. Below that the server would not have returned the card at
  /// all — its floor is 34% — so `loose` covers a real but distant match.
  static _Band of(int percent) {
    if (percent >= 85) return _Band.strong;
    if (percent >= 65) return _Band.good;
    return _Band.loose;
  }
}
