import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_typography.dart';

/// A premium, self-ticking countdown — segmented "flip card" boxes for
/// days / hours / minutes / seconds. Drives flash deals, limited drops and any
/// time-boxed moment.
///
/// Ticks once per second and disposes its timer automatically. Days collapse
/// when zero. Fires [onExpired] exactly once when the deadline passes.
class DsCountdownTimer extends StatefulWidget {
  const DsCountdownTimer({
    super.key,
    required this.endsAt,
    this.onExpired,
    this.compact = false,
    this.boxColor,
    this.foreground,
    this.separatorColor,
  });

  final DateTime endsAt;
  final VoidCallback? onExpired;

  /// Smaller boxes for dense card layouts.
  final bool compact;

  /// Override the segment box fill (defaults to a tinted surface).
  final Color? boxColor;

  /// Override the digit color.
  final Color? foreground;

  /// Override the ":" separator color.
  final Color? separatorColor;

  @override
  State<DsCountdownTimer> createState() => _DsCountdownTimerState();
}

class _DsCountdownTimerState extends State<DsCountdownTimer> {
  Timer? _timer;
  late Duration _remaining;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant DsCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _notified = false;
      setState(() => _remaining = _compute());
    }
  }

  Duration _compute() {
    final diff = widget.endsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _tick() {
    if (!mounted) return;
    final next = _compute();
    setState(() => _remaining = next);
    if (next == Duration.zero && !_notified) {
      _notified = true;
      _timer?.cancel();
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    final boxColor = widget.boxColor ?? c.onSurface.withValues(alpha: 0.06);
    final fg = widget.foreground ?? c.onSurface;
    final sep = widget.separatorColor ?? c.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (days > 0) ...[
          _Segment(value: days, label: 'd', boxColor: boxColor, fg: fg, compact: widget.compact),
          _Separator(color: sep, compact: widget.compact),
        ],
        _Segment(value: hours, label: 'h', boxColor: boxColor, fg: fg, compact: widget.compact),
        _Separator(color: sep, compact: widget.compact),
        _Segment(value: minutes, label: 'm', boxColor: boxColor, fg: fg, compact: widget.compact),
        _Separator(color: sep, compact: widget.compact),
        _Segment(value: seconds, label: 's', boxColor: boxColor, fg: fg, compact: widget.compact),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.value,
    required this.label,
    required this.boxColor,
    required this.fg,
    required this.compact,
  });

  final int value;
  final String label;
  final Color boxColor;
  final Color fg;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 26.0 : 34.0;
    final fontSize = compact ? 13.0 : 16.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(compact ? DsRadius.sm : DsRadius.md),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: fontSize,
              fontWeight: DsTypography.bold,
              color: fg,
              height: 1,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 3),
          Text(
            label,
            style: context.dsText.caption.tint(fg.withValues(alpha: 0.6)),
          ),
        ],
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color, required this.compact});

  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
      child: Padding(
        // Nudge up so the ":" centres against the digit boxes, not the labels.
        padding: EdgeInsets.only(bottom: compact ? 0 : 16),
        child: Text(
          ':',
          style: TextStyle(
            fontSize: compact ? 13 : 16,
            fontWeight: DsTypography.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
