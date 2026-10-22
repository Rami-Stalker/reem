import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds once a second with the time left until [endsAt], as `HH:MM:SS`.
///
/// Hours are not wrapped at a day: «27:04:10» reads as "a bit over a day",
/// which is what a deal ending tomorrow evening should feel like. When the
/// moment passes the widget stops ticking and shows `00:00:00`.
class LiveCountdown extends StatefulWidget {
  const LiveCountdown({super.key, required this.endsAt, required this.builder});

  final DateTime endsAt;
  final Widget Function(BuildContext context, String remaining) builder;

  /// `HH:MM:SS` for [left], never negative.
  static String format(Duration left) {
    final clamped = left.isNegative ? Duration.zero : left;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(clamped.inHours)}:${two(clamped.inMinutes % 60)}:'
        '${two(clamped.inSeconds % 60)}';
  }

  @override
  State<LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<LiveCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.endsAt.isBefore(DateTime.now())) _timer?.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    LiveCountdown.format(widget.endsAt.difference(DateTime.now())),
  );
}
