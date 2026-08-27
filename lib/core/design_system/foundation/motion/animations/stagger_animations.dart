import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';

abstract final class DsStaggerAnimations {
  static Widget list({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    Duration delay = const Duration(milliseconds: 50),
  }) {
    return AnimationLimiter(
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            delay: delay,
            duration: DsMotion.normal,
            child: SlideAnimation(
              verticalOffset: 24,
              child: FadeInAnimation(child: itemBuilder(context, index)),
            ),
          );
        },
      ),
    );
  }
}
