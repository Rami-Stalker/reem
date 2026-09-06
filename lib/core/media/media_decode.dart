import 'package:flutter/widgets.dart';

/// How large an image should actually be rasterised.
///
/// Downloading a 480px thumbnail instead of the original saves bytes on the
/// wire; this saves the memory those bytes turn into. A photograph decoded at
/// its natural size into a 74px tile costs roughly the same texture as one
/// filling the screen — around a megabyte of ARGB either way — so a grid of
/// twenty tiles can hold twenty megabytes of pixels nobody can see. On the
/// mid-range handsets this platform serves, that is the difference between a
/// list that scrolls and one that stutters and then drops its images.
abstract final class MediaDecode {
  /// [logicalWidth] in device pixels, which is the most detail the screen can
  /// resolve. Null when the width is unknown or unbounded — a full-bleed hero,
  /// where guessing low would visibly soften the picture.
  static int? widthFor(BuildContext context, double? logicalWidth) {
    if (logicalWidth == null ||
        !logicalWidth.isFinite ||
        logicalWidth <= 0) {
      return null;
    }
    return (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
  }

  /// The same budget, taken from the constraints a parent handed down.
  static int? widthFrom(BuildContext context, BoxConstraints constraints) =>
      constraints.hasBoundedWidth
          ? widthFor(context, constraints.maxWidth)
          : null;
}
