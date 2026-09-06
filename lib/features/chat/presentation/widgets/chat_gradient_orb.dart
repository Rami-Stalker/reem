import 'dart:math';

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// A slow rose bloom drifting behind a conversation.
///
/// Decoration, not content — it is what keeps a thread from reading as a flat
/// grey list. The tint comes off the theme so it warms the light ground and
/// glows against the dark one, instead of being a fixed pink that only worked
/// in one mode.
class ChatGradientOrb extends StatefulWidget {
  const ChatGradientOrb({super.key});

  @override
  State<ChatGradientOrb> createState() => _ChatGradientOrbState();
}

class _ChatGradientOrbState extends State<ChatGradientOrb>
    with SingleTickerProviderStateMixin {
  /// One slow lap. Long enough that the motion is felt rather than watched.
  static const Duration _lap = Duration(seconds: 12);
  static const double _diameter = 240;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DsReducedMotion.duration(_lap),
  );

  @override
  void initState() {
    super.initState();
    // Repeating forever is the point, but only when motion is welcome: a
    // reduced-motion device gets a still bloom rather than a live ticker.
    if (!DsReducedMotion.isEnabled) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    // The controller repeats forever, so without this every conversation left
    // a live ticker behind it — the framework says as much at teardown, and on
    // a device it is a slow leak nobody would connect to chat.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = context.dsColors.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          sin(_controller.value * pi * 2) * 30,
          cos(_controller.value * pi * 2) * 20,
        ),
        child: child,
      ),
      child: Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              tint.withValues(alpha: DsOpacity.medium),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
