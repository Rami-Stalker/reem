import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// Grid system constants (12-column layout). Gutters and margins are spacing
/// tokens, not independent numbers.
abstract final class DsGrid {
  static const int columns = 12;
  static const double gutter = DsSpacing.md;
  static const double gutterCompact = DsSpacing.sm;
  static const double gutterExpanded = DsSpacing.xl;
  static const double margin = DsSpacing.md;
  static const double marginExpanded = DsSpacing.xl;

  static double columnWidth(double containerWidth, {int span = 1}) {
    final totalGutter = gutter * (columns - 1);
    final columnUnit = (containerWidth - totalGutter) / columns;
    return columnUnit * span + gutter * (span - 1);
  }
}
