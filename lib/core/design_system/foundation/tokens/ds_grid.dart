/// Grid system constants (12-column layout).
abstract final class DsGrid {
  static const int columns = 12;
  static const double gutter = 16;
  static const double gutterCompact = 12;
  static const double gutterExpanded = 24;
  static const double margin = 16;
  static const double marginExpanded = 24;

  static double columnWidth(double containerWidth, {int span = 1}) {
    final totalGutter = gutter * (columns - 1);
    final columnUnit = (containerWidth - totalGutter) / columns;
    return columnUnit * span + gutter * (span - 1);
  }
}
