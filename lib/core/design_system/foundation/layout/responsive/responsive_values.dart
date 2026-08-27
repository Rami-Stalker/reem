import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/layout/responsive/screen_size.dart';

/// Holds values per breakpoint with fallback chain.
class ResponsiveValues<T> {
  const ResponsiveValues({
    required this.compact,
    this.medium,
    this.expanded,
    this.large,
  });

  final T compact;
  final T? medium;
  final T? expanded;
  final T? large;

  T resolve(BuildContext context) {
    return switch (context.screenSize) {
      ScreenSize.compact => compact,
      ScreenSize.medium => medium ?? compact,
      ScreenSize.expanded => expanded ?? medium ?? compact,
      ScreenSize.large => large ?? expanded ?? medium ?? compact,
    };
  }
}
