import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Ohara's arch: the pointed window of an old Damascus house.
///
/// Straight jambs, two curves meeting at the crown, softly rounded feet. It is
/// the frame of the sign-in emblem and of every profile portrait, so the shape
/// is defined once, here.
Path dsArchPath(Rect r) {
  final w = r.width;
  final spring = r.top + w * 0.6;
  final foot = math.min(w * 0.16, r.height * 0.12);
  return Path()
    ..moveTo(r.left, r.bottom - foot)
    ..lineTo(r.left, spring)
    ..cubicTo(
      r.left,
      r.top + w * 0.26,
      r.left + w * 0.30,
      r.top + w * 0.07,
      r.center.dx,
      r.top,
    )
    ..cubicTo(
      r.right - w * 0.30,
      r.top + w * 0.07,
      r.right,
      r.top + w * 0.26,
      r.right,
      spring,
    )
    ..lineTo(r.right, r.bottom - foot)
    ..quadraticBezierTo(r.right, r.bottom, r.right - foot, r.bottom)
    ..lineTo(r.left + foot, r.bottom)
    ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - foot)
    ..close();
}

/// Clips a child to [dsArchPath], inset by [inset] on every side.
class DsArchClipper extends CustomClipper<Path> {
  const DsArchClipper({this.inset = 0});

  final double inset;

  @override
  Path getClip(Size size) => dsArchPath((Offset.zero & size).deflate(inset));

  @override
  bool shouldReclip(DsArchClipper oldClipper) => oldClipper.inset != inset;
}
