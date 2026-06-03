import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../tokens/ds_motion.dart';
import '../curves/ds_curves.dart';

CustomTransitionPage<T> dsFadeTransitionPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: DsMotion.normal,
    reverseTransitionDuration: DsMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: DsCurves.standard),
        child: child,
      );
    },
  );
}
