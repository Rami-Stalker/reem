import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedCounter
    extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration =
        const Duration(seconds: 2),
    this.style,
  });

  @override
  State<AnimatedCounter>
      createState() =>
          _AnimatedCounterState();
}

class _AnimatedCounterState
    extends State<AnimatedCounter> {
  int current = 0;

  @override
  void initState() {
    super.initState();

    final stepDuration =
        widget.duration.inMilliseconds ~/
            widget.value;

    Timer.periodic(
      Duration(
          milliseconds: stepDuration),
      (timer) {
        if (current >= widget.value) {
          timer.cancel();
        } else {
          setState(() {
            current++;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      current.toString(),
      style: widget.style,
    );
  }
}