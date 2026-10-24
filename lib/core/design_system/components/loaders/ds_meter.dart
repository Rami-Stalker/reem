import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';

/// How far along something is: a room's readiness, a mission, a pillar of
/// her standing, a bar in a chart.
///
/// Thirteen screens drew this by hand — a rounded clip around a
/// `LinearProgressIndicator`, each with its own height and track — so the
/// same idea came out five different thicknesses across the app. This is
/// that bar, once. [height] picks from three weights rather than any number,
/// for the same reason.
class DsMeter extends StatelessWidget {
  const DsMeter({
    super.key,
    required this.value,
    this.weight = DsMeterWeight.regular,
    this.color,
    this.track,
    this.semanticLabel,
  });

  /// 0–1; clamped, so a value a hair over the top draws full rather than
  /// throwing. Null while the total is not known yet — a voice note before
  /// its length arrives — and the bar moves without claiming a position.
  final double? value;

  final DsMeterWeight weight;

  /// The fill. Defaults to the brand primary.
  final Color? color;

  /// The empty part. Defaults to the surface variant.
  final Color? track;

  /// Read out in place of the bare percentage, when there is a better name
  /// for what is measured.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final raw = value;
    final clamped = raw == null || raw.isNaN ? null : raw.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      value: clamped == null ? null : '${(clamped * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: DsRadius.borderPill,
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: weight.height,
            color: color ?? c.primary,
            backgroundColor: track ?? c.surfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The three thicknesses a meter comes in.
enum DsMeterWeight {
  /// Inside a card row, beside a label.
  thin(4),

  /// The default: a standalone progress line.
  regular(6),

  /// A bar in a chart, where the bar *is* the reading.
  bold(10);

  const DsMeterWeight(this.height);

  final double height;
}
