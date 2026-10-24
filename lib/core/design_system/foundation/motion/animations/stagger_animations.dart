import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:ohara/core/design_system/foundation/theme/accessibility/reduced_motion_theme.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_motion.dart';

abstract final class DsStaggerAnimations {
  /// One entry of a staggered reveal, for grids and sliver lists where the
  /// [list] helper's own `ListView` does not fit.
  ///
  /// Entrances across the app were hand-tuned per screen — 100ms steps here,
  /// 60ms there, some scaling from 0.9 and some sliding 24px. This is the one
  /// entrance: a short rise and fade, with the step capped so the tail of a
  /// long grid is not still animating in when she has already scrolled past.
  static Widget item({
    required int index,
    required Widget child,
    Duration step = const Duration(milliseconds: 45),
    int maxSteps = 8,
  }) {
    final position = index < maxSteps ? index : maxSteps;
    return _StaggeredEntrance(
      delay: step * position,
      child: child,
    );
  }

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

class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DsReducedMotion.duration(DsMotion.moderate),
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: DsReducedMotion.curve(DsMotion.emphasized),
  );

  Timer? _start;

  @override
  void initState() {
    super.initState();
    // The delay is skipped entirely when the platform asks for reduced motion,
    // so the grid appears at once rather than crawling in.
    final delay = DsReducedMotion.duration(widget.delay);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _start = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
