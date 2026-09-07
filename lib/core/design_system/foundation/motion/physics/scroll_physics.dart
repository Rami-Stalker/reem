import 'package:flutter/material.dart';

/// The only two scroll physics a screen should ever name.
///
/// There used to be a `standard` here that was `BouncingScrollPhysics`, and
/// naming it "standard" is how iOS bounce ended up hardcoded on a dozen
/// Android surfaces. Ordinary scrolling now names nothing at all and lets
/// `AppScrollBehavior` answer per platform; the two cases below are the ones
/// where the widget really does know better than the platform.
abstract final class DsScrollPhysics {
  /// A list nested inside another scrollable, which must not scroll itself.
  static const ScrollPhysics never = NeverScrollableScrollPhysics();

  /// A scrollable that must accept a drag even when its content fits — the
  /// precondition for pull-to-refresh on a short page.
  static const ScrollPhysics alwaysScrollable = AlwaysScrollableScrollPhysics();
}
