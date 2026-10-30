import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/gradient_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_typography.dart';

/// The three places the mark is drawn, each at its own size and tracking.
enum OharaWordmarkSize {
  /// Inside a top bar, beside icons.
  bar(fontSize: 26, tracking: 0.10),

  /// A quiet signature at the foot of a page or in a side panel.
  footer(fontSize: 18, tracking: 0.16),

  /// The splash and other full-screen moments.
  hero(fontSize: 54, tracking: 0.14);

  const OharaWordmarkSize({required this.fontSize, required this.tracking});

  final double fontSize;

  /// Letter spacing as a fraction of the font size, so the mark keeps its
  /// proportions at every size.
  final double tracking;
}

/// The OHARA wordmark, set in Cinzel Decorative.
///
/// It is a logo, so it reads the same in Arabic and in English: always the
/// Latin capitals, always left to right. Screen readers hear the localised
/// name ([semanticLabel], normally `l10n.appTitle`) instead of five letters.
///
/// Pass [color] for a solid mark (a bar tinted to its background); otherwise
/// the mark is filled with [gradient], or the brand gradient by default.
class OharaWordmark extends StatelessWidget {
  const OharaWordmark({
    super.key,
    required this.semanticLabel,
    this.size = OharaWordmarkSize.bar,
    this.color,
    this.gradient,
  });

  static const String _mark = 'OHARA';

  final String semanticLabel;
  final OharaWordmarkSize size;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final spacing = size.fontSize * size.tracking;
    final style = TextStyle(
      fontFamily: DsTypography.fontFamilyBrand,
      fontWeight: FontWeight.w700,
      fontSize: size.fontSize,
      letterSpacing: spacing,
      height: 1.15,
      color: color ?? DsColors.onMedia,
    );

    // Tracking also follows the last letter; the same space before the first
    // one keeps the mark optically centred wherever it is centred.
    Widget mark = Padding(
      padding: EdgeInsets.only(left: spacing),
      child: Text(
        _mark,
        style: style,
        maxLines: 1,
        softWrap: false,
        textDirection: TextDirection.ltr,
        // The mark is a fixed size; system text scaling would let it outgrow
        // the bar it sits in.
        textScaler: TextScaler.noScaling,
      ),
    );

    if (color == null) {
      mark = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) =>
            (gradient ?? context.primaryGradient).createShader(bounds),
        child: mark,
      );
    }

    return Semantics(
      label: semanticLabel,
      header: true,
      excludeSemantics: true,
      child: mark,
    );
  }
}
