/// The one size scale for fixed-dimension UI furniture.
///
/// Icon, avatar, control and media dimensions were previously spread across
/// three half-overlapping token classes (`DsIcons.size*`, `DsConstraints.icon*`
/// and whatever literal the widget author picked), which is why the same
/// "small icon" was 16, 17, 18 and 20 in four different files. Everything with
/// a fixed pixel dimension now resolves here, and the older classes forward to
/// these values so there is a single number behind each name.
abstract final class DsSizes {
  // Icons --------------------------------------------------------------------
  /// Inline with caption text.
  static const double iconXxs = 12;

  /// Inline with body text, chip leading icons.
  static const double iconXs = 16;

  /// Default for dense rows, list leading icons, buttons.
  static const double iconSm = 20;

  /// Default standalone icon — app bar actions, tab bar.
  static const double iconMd = 24;

  /// Feature icons inside tiles and cards.
  static const double iconLg = 32;

  /// Empty-state and onboarding illustration glyphs.
  static const double iconXl = 40;
  static const double iconXxl = 56;
  static const double iconHero = 72;

  // Avatars ------------------------------------------------------------------
  static const double avatarXxs = 20;
  static const double avatarXs = 28;
  static const double avatarSm = 36;
  static const double avatarMd = 44;
  static const double avatarLg = 56;
  static const double avatarXl = 72;
  static const double avatarHero = 96;

  /// Story ring outer diameter.
  static const double storyRing = 72;

  // Controls -----------------------------------------------------------------
  /// WCAG / Material minimum tappable square.
  static const double minTouchTarget = 48;

  static const double controlSm = 36;
  static const double controlMd = 44;
  static const double controlLg = 52;
  static const double controlXl = 62;

  static const double chipHeight = 36;
  static const double fieldHeight = 52;
  static const double fabSize = 56;

  // Chrome -------------------------------------------------------------------
  static const double appBarHeight = 56;
  static const double appBarExpanded = 100;
  static const double bottomBarHeight = 72;
  static const double sheetHandleWidth = 44;
  static const double sheetHandleHeight = 4;
  static const double dividerThickness = 1;

  // Media --------------------------------------------------------------------
  /// Square thumbnail in a list row.
  static const double thumbSm = 56;
  static const double thumbMd = 72;
  static const double thumbLg = 96;

  /// Product tile image height inside a horizontal rail.
  static const double railCardWidth = 160;
  static const double railCardHeight = 240;

  /// Aspect ratios for product imagery — portrait is the brand default.
  static const double aspectPortrait = 3 / 4;
  static const double aspectSquare = 1;
  static const double aspectLandscape = 16 / 9;
  static const double aspectProductCard = 0.68;

  // Content widths -----------------------------------------------------------
  static const double maxContentWidth = 600;
  static const double maxFormWidth = 480;
  static const double maxDialogWidth = 400;

  /// Clearance under scrollable content so it can pass a floating bar / FAB.
  static const double bottomSafeGap = 88;
}
