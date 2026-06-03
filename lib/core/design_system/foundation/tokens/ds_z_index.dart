/// Z-order layers for overlays and stacking contexts.
abstract final class DsZIndex {
  static const int base = 0;
  static const int dropdown = 100;
  static const int sticky = 200;
  static const int fixed = 300;
  static const int appBar = 400;
  static const int drawer = 500;
  static const int bottomBar = 600;
  static const int modal = 700;
  static const int popover = 800;
  static const int tooltip = 900;
  static const int toast = 1000;
  static const int overlay = 1100;
  static const int max = 9999;
}
