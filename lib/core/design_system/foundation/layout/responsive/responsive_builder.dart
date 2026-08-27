import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/layout/responsive/screen_size.dart';

typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  ScreenSize screenSize,
);

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final ResponsiveWidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context, context.screenSize);
}
