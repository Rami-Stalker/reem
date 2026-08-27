import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/media/authorized_media_image.dart';

/// A voice note, with a way to hear it.
///
/// What this replaced took no URL and no duration: a play button that flipped a
/// boolean, over a row of bars whose heights were a fixed list. It looked like
/// a voice message and could not play one.
///
/// The player is created on first press rather than on build. A conversation
/// with thirty voice notes would otherwise open thirty audio players, each
/// holding a platform decoder, to sit idle.
class VoiceMessageBubble extends ConsumerStatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.url,
    this.isMe = false,
    this.duration,
  });

  final String url;
  final bool isMe;

  /// As measured by the sender's recorder. Shown before the file is fetched,
  /// so the bubble says how long it is without downloading it first.
  final Duration? duration;

  @override
  ConsumerState<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends ConsumerState<VoiceMessageBubble> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final existing = _player;
    if (existing != null) {
      if (_playing) {
        await existing.pause();
      } else {
        // Restart rather than resume from the end of a finished note.
        if (existing.processingState == ProcessingState.completed) {
          await existing.seek(Duration.zero);
        }
        await existing.play();
      }
      return;
    }

    setState(() => _loading = true);
    final player = AudioPlayer();
    _player = player;

    _stateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state.playing && state.processingState != ProcessingState.completed;
        _loading = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });
    _positionSub = player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    try {
      // Chat media sits behind an authorised endpoint, so the player needs the
      // same bearer token the image loader does — and for the same reason:
      // neither goes through Dio.
      final headers = await ref.read(mediaAuthHeadersProvider.future);
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(widget.url),
          headers: headers.isEmpty ? null : headers,
        ),
      );
      await player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final total = _player?.duration ?? widget.duration ?? Duration.zero;
    final onBubble = widget.isMe ? Colors.white : c.onSurface;

    return Align(
      // Directional, not absolute: the sender's own bubble sits on the trailing
      // edge of the reading direction, which flips with the locale instead of
      // staying pinned to a physical side.
      alignment: widget.isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: widget.isMe ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(DsRadius.xxl),
          border: widget.isMe ? null : Border.all(color: c.border),
        ),
        child: _failed
            ? Text(
                context.l10n.voiceUnavailable,
                style: TextStyle(color: onBubble.withValues(alpha: 0.8)),
              )
            : Row(
                children: [
                  _PlayButton(
                    playing: _playing,
                    loading: _loading,
                    tint: widget.isMe ? Colors.white : c.primary,
                    onTap: _toggle,
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(DsRadius.full),
                          child: LinearProgressIndicator(
                            value: _progress(total),
                            minHeight: 4,
                            color: onBubble,
                            backgroundColor: onBubble.withValues(alpha: 0.25),
                          ),
                        ),
                        const SizedBox(height: DsSpacing.xs),
                        Text(
                          // Counts up while playing, shows the length at rest —
                          // the two things she wants at the two moments she
                          // wants them.
                          _format(_playing || _position > Duration.zero
                              ? _position
                              : total),
                          style: TextStyle(
                            color: onBubble.withValues(alpha: 0.85),
                            fontSize: DsTypography.labelSmall,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  double? _progress(Duration total) {
    if (total <= Duration.zero) return _loading ? null : 0;
    return (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  static String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.loading,
    required this.tint,
    required this.onTap,
  });

  final bool playing;
  final bool loading;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: loading
          ? Padding(
              padding: const EdgeInsets.all(DsSpacing.xs),
              child: CircularProgressIndicator(strokeWidth: 2, color: tint),
            )
          : IconButton(
              onPressed: onTap,
              padding: EdgeInsets.zero,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: tint,
                size: 30,
              ),
            ),
    );
  }
}
