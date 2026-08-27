import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/voice_recorder_service.dart';

/// The composer while a voice note is being recorded.
///
/// Tap to start, then send or discard — not hold-to-talk. Holding a button
/// steady for thirty seconds is a poor bargain on a phone being held one-handed
/// on a bus, and a finger that slips loses the whole recording. The trade is one
/// extra tap for a recording that cannot be lost by accident.
class VoiceRecorderBar extends ConsumerStatefulWidget {
  const VoiceRecorderBar({
    super.key,
    required this.onCompleted,
    required this.onCancelled,
  });

  /// The finished recording: where it is, and how long it runs. Duration is
  /// measured here rather than read back from the file — the recorder knows it
  /// exactly, and decoding a container to recover a number we already had would
  /// be work for nothing.
  final void Function(String path, Duration duration) onCompleted;

  final VoidCallback onCancelled;

  @override
  ConsumerState<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends ConsumerState<VoiceRecorderBar> {
  /// Resolved once, in `initState`. `ref` leans on `BuildContext`, and both
  /// finishing paths run after an `await` — by which time this widget may have
  /// been taken out of the tree, and Riverpod refuses the read outright.
  late final VoiceRecorderService _recorder = ref.read(
    voiceRecorderServiceProvider,
  );

  Timer? _ticker;
  StreamSubscription<double>? _levelSub;
  Duration _elapsed = Duration.zero;
  double _level = 0;
  bool _recording = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _levelSub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final recorder = _recorder;

    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      DsSnackbar.show(
        context,
        message: context.l10n.voicePermissionDenied,
        type: DsSnackbarType.warning,
      );
      widget.onCancelled();
      return;
    }

    try {
      await recorder.start();
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.show(
        context,
        message: context.l10n.voiceRecordFailed,
        type: DsSnackbarType.error,
      );
      widget.onCancelled();
      return;
    }
    if (!mounted) return;

    setState(() => _recording = true);
    _levelSub = recorder.levels.listen((level) {
      if (mounted) setState(() => _level = level);
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final next = _elapsed + const Duration(milliseconds: 200);
      setState(() => _elapsed = next);
      // Stops itself rather than recording her pocket indefinitely.
      if (next >= VoiceRecorderService.maxDuration) _send();
    });
  }

  Future<void> _send() async {
    if (_finishing) return;
    _finishing = true;
    // Not awaited, either here or in `_cancel`. Nothing downstream depends on
    // the amplitude stream having finished closing, and awaiting it puts an
    // event-loop turn between her pressing send and the recorder stopping —
    // which is the one moment where the delay is hers to notice.
    _stopListening();

    final path = await _recorder.stop();
    if (!mounted) return;

    // Under a second is a slip of the thumb, not a message.
    if (path == null || _elapsed < const Duration(seconds: 1)) {
      widget.onCancelled();
      return;
    }
    widget.onCompleted(path, _elapsed);
  }

  Future<void> _cancel() async {
    if (_finishing) return;
    _finishing = true;
    _stopListening();
    await _recorder.cancel();
    if (mounted) widget.onCancelled();
  }

  void _stopListening() {
    _ticker?.cancel();
    unawaited(_levelSub?.cancel() ?? Future<void>.value());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.sm,
        DsSpacing.md,
        DsSpacing.lg,
      ),
      color: c.surface,
      child: Row(
        children: [
          IconButton(
            onPressed: _cancel,
            icon: Icon(Icons.delete_outline_rounded, color: c.error),
            tooltip: context.l10n.cancel,
          ),
          _RecordingDot(active: _recording),
          const SizedBox(width: DsSpacing.xs),
          Text(
            _format(_elapsed),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: DsTypography.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(child: _Level(value: _level, color: c.primary)),
          const SizedBox(width: DsSpacing.sm),
          IconButton.filled(
            onPressed: _recording ? _send : null,
            icon: const Icon(Icons.send_rounded),
            tooltip: context.l10n.voiceSend,
          ),
        ],
      ),
    );
  }

  /// `m:ss`, with tabular figures above so the row does not jitter every time
  /// a digit changes width.
  static String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1 : 0.3,
      duration: const Duration(milliseconds: 400),
      child: Icon(Icons.circle, size: 10, color: context.dsColors.error),
    );
  }
}

/// A bar that follows her voice. Not a waveform: drawing a real one means
/// keeping every sample, and this only has to say "it is hearing you".
class _Level extends StatelessWidget {
  const _Level({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DsRadius.full),
      child: LinearProgressIndicator(
        value: value.clamp(0.05, 1.0),
        minHeight: 6,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }
}
