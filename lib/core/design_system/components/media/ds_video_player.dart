import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A clip that plays when she is looking at it and stops when she is not.
///
/// The project had no video player before this. `MediaType.video` was modelled
/// throughout, accepted by the upload endpoint, and drawn as a still with a
/// play icon that did nothing — and a video story went through
/// `CachedNetworkImage`, which cannot decode one, so it rendered as a broken
/// frame.
///
/// Three properties matter more than the widget tree:
///
/// **One decoder at a time.** A reels list is a `PageView` of full-screen
/// clips, and initialising a controller per item opens a platform decoder per
/// item — which on a mid-range Android handset is how the app is killed. Only
/// the visible item holds a controller; everything else is a poster. It is the
/// same discipline `VoiceMessageBubble` already applies to `just_audio`, for
/// the same reason.
///
/// **Muted by default.** She may be on a bus, or beside someone. Sound is a
/// deliberate tap, and the choice is remembered for the session so she does not
/// have to make it on every clip.
///
/// **It never touches `ref` after an `await`.** Riverpod 3 refuses that, and it
/// is a bug this repository has shipped twice — in `ChatDetailsScreen.dispose`
/// and in `VoiceRecorderBar`.
class DsVideoPlayer extends StatefulWidget {
  const DsVideoPlayer({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.blurHash,
    this.autoplay = true,
    this.loop = true,
    this.showControls = true,
    this.fit = BoxFit.cover,
    this.onWatched,
    this.onTap,
    this.mutePlacement = DsVideoMutePlacement.bottomEnd,
    this.paused = false,
    this.onReady,
  });

  final String url;

  /// Drawn until the first frame arrives. Falls back to the blur hash, which
  /// every uploaded image carries, so there is never a blank rectangle.
  final String? thumbnailUrl;
  final String? blurHash;

  /// Play when at least [_visibleEnough] of the widget is on screen.
  final bool autoplay;
  final bool loop;
  final bool showControls;
  final BoxFit fit;

  /// Called with how long she actually watched, when the clip leaves the
  /// screen or the widget is disposed. This is what feeds `WATCH_TIME`.
  final void Function(Duration watched)? onWatched;

  /// A tap that is not the mute toggle — opening the piece, usually.
  final VoidCallback? onTap;

  /// Where the sound toggle sits. A full-screen reel carries its own action
  /// rail at the bottom corner, and the toggle drawn there was hidden under
  /// it — so a reel puts it at the top, under the app bar.
  final DsVideoMutePlacement mutePlacement;

  /// Held by the caller — a story frame she is pressing on, or a sheet open
  /// over the clip. Releasing it resumes where it stopped.
  final bool paused;

  /// The clip's length, once the decoder knows it. A story viewer times its
  /// progress bar by this rather than by a fixed dwell.
  final ValueChanged<Duration>? onReady;

  @override
  State<DsVideoPlayer> createState() => _DsVideoPlayerState();
}

/// Where [DsVideoPlayer] draws its sound toggle.
enum DsVideoMutePlacement { bottomEnd, topEnd }

/// Enough of the clip on screen to be worth a decoder.
const double _visibleEnough = 0.6;

/// Session-wide, deliberately not persisted. Unmuting is a decision about
/// *now* — she is alone, or wearing headphones — not a preference that should
/// still hold tomorrow morning on a bus.
///
/// A notifier, so a surface that draws its own sound toggle (the story
/// viewer, whose taps belong to navigation) flips every playing clip at once.
final ValueNotifier<bool> dsVideoSessionMuted = ValueNotifier<bool>(true);

bool get _mutedForSession => dsVideoSessionMuted.value;

class _DsVideoPlayerState extends State<DsVideoPlayer> {
  @override
  void initState() {
    super.initState();
    dsVideoSessionMuted.addListener(_onSessionMute);
  }

  void _onSessionMute() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(controller.setVolume(_mutedForSession ? 0 : 1));
    if (mounted) setState(() {});
  }

  VideoPlayerController? _controller;
  bool _initialising = false;
  bool _visible = false;
  Duration _watched = Duration.zero;
  DateTime? _playingSince;

  @override
  void didUpdateWidget(covariant DsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled tile pointed at a different clip must not keep playing the
    // old one — the failure that looks like the list showing the wrong video.
    if (oldWidget.url != widget.url) {
      _release();
      if (_visible) unawaited(_ensureController());
      return;
    }
    if (oldWidget.paused != widget.paused) {
      final controller = _controller;
      if (controller == null) return;
      if (widget.paused) {
        _accrue();
        unawaited(controller.pause());
      } else if (widget.autoplay) {
        _playingSince = DateTime.now();
        unawaited(controller.play());
      }
    }
  }

  @override
  void dispose() {
    dsVideoSessionMuted.removeListener(_onSessionMute);
    _release();
    super.dispose();
  }

  void _release() {
    _accrue();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerTick);
      // Not awaited: `dispose` cannot be async, and the platform view is torn
      // down either way.
      unawaited(controller.pause().then((_) => controller.dispose()));
    }
    if (_watched > Duration.zero) {
      widget.onWatched?.call(_watched);
      _watched = Duration.zero;
    }
  }

  /// Time actually spent playing, accumulated across pauses.
  void _accrue() {
    final since = _playingSince;
    if (since == null) return;
    _watched += DateTime.now().difference(since);
    _playingSince = null;
  }

  Future<void> _ensureController() async {
    if (_controller != null || _initialising) return;
    _initialising = true;

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
    } catch (_) {
      // A clip that will not decode is a poster, not a crash. The thumbnail or
      // blur hash below is already the right thing to show.
      await controller.dispose();
      _initialising = false;
      if (mounted) setState(() {});
      return;
    }

    // She may have scrolled past while it was loading, or the widget may be
    // gone entirely.
    if (!mounted || !_visible) {
      await controller.dispose();
      _initialising = false;
      return;
    }

    await controller.setLooping(widget.loop);
    await controller.setVolume(_mutedForSession ? 0 : 1);
    controller.addListener(_onControllerTick);

    setState(() {
      _controller = controller;
      _initialising = false;
    });
    widget.onReady?.call(controller.value.duration);

    if (widget.autoplay && !widget.paused) {
      _playingSince = DateTime.now();
      await controller.play();
    }
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  Future<void> _onVisibility(VisibilityInfo info) async {
    final visible = info.visibleFraction >= _visibleEnough;
    if (visible == _visible) return;
    _visible = visible;

    if (!visible) {
      _release();
      if (mounted) setState(() {});
      return;
    }
    await _ensureController();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    // The listener applies the volume to this clip and every other one.
    dsVideoSessionMuted.value = !_mutedForSession;
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      _accrue();
      await controller.pause();
    } else {
      _playingSince = DateTime.now();
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return VisibilityDetector(
      // `VisibilityDetector` needs a key unique per clip, so a recycled tile is
      // not mistaken for the one it replaced.
      // l10n-ignore: a widget identity, not copy.
      key: Key('ds-video-${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: widget.onTap ?? (widget.showControls ? _togglePlay : null),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Poster(
              thumbnailUrl: widget.thumbnailUrl,
              blurHash: widget.blurHash,
              fit: widget.fit,
            ),
            if (ready)
              FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            if (ready && widget.showControls) ...[
              _MuteButton(
                muted: _mutedForSession,
                onTap: _toggleMute,
                placement: widget.mutePlacement,
              ),
              if (!controller.value.isPlaying) const _PlayGlyph(),
              _Progress(controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

/// What fills the frame before — and instead of — the first decoded frame.
class _Poster extends StatelessWidget {
  const _Poster({this.thumbnailUrl, this.blurHash, required this.fit});

  final String? thumbnailUrl;
  final String? blurHash;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final hash = blurHash;
    final thumb = thumbnailUrl;

    if (thumb != null && thumb.isNotEmpty) {
      // A reel's poster is the frame the whole list is scrolled past, so it
      // has to come from the cache rather than the wire on every pass — and a
      // clip uploaded into a conversation is a private asset that `Image
      // .network` could not authenticate for at all.
      return AuthorizedMediaImage(
        url: thumb,
        fit: fit,
        fallback: _hashOrGround(hash),
      );
    }
    return _hashOrGround(hash);
  }

  Widget _hashOrGround(String? hash) {
    if (hash != null && hash.isNotEmpty) {
      return BlurHash(hash: hash, imageFit: fit);
    }
    // A colour rather than nothing: an empty frame reads as a broken player.
    return const ColoredBox(color: DsColors.mediaGround);
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({
    required this.muted,
    required this.onTap,
    required this.placement,
  });

  final bool muted;
  final VoidCallback onTap;
  final DsVideoMutePlacement placement;

  @override
  Widget build(BuildContext context) {
    final top = placement == DsVideoMutePlacement.topEnd;
    return Positioned(
      right: DsSpacing.md,
      bottom: top ? null : DsSpacing.xl,
      top: top
          ? MediaQuery.paddingOf(context).top + kToolbarHeight + DsSpacing.sm
          : null,
      child: Semantics(
        button: true,
        label: muted ? context.l10n.a11yUnmute : context.l10n.a11yMute,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(DsSpacing.sm),
            decoration: BoxDecoration(
              color: DsColors.mediaScrim,
              shape: BoxShape.circle,
            ),
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: DsSizes.iconSm,
              color: DsColors.onMedia,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: DsColors.mediaScrim,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: DsSizes.iconLg,
          color: DsColors.onMedia,
        ),
      ),
    );
  }
}

/// A hairline, not a scrubber. A reel is watched, not navigated.
class _Progress extends StatelessWidget {
  const _Progress({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final total = value.duration.inMilliseconds;
    final progress = total <= 0
        ? 0.0
        : (value.position.inMilliseconds / total).clamp(0.0, 1.0);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 2,
        backgroundColor: DsColors.onMediaFaint,
        valueColor: const AlwaysStoppedAnimation<Color>(DsColors.onMedia),
      ),
    );
  }
}
