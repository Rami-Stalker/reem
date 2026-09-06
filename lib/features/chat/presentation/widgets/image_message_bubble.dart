import 'package:flutter/material.dart';

import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_lightbox.dart';
import 'package:reem/core/media/media_variants.dart';

/// A photograph in a conversation.
///
/// Two things this used to do are gone. It fetched with `Image.network`, which
/// carries no session and therefore draws an error box for every photograph
/// sent through chat — those live behind an authorised endpoint. And it painted
/// a "2.4k ♥" badge over every image, a leftover from the mock that would have
/// shipped as a like count nobody could explain.
class ImageMessageBubble extends StatelessWidget {
  const ImageMessageBubble({
    super.key,
    required this.image,
    this.isMe = false,
    this.width,
    this.height,
  });

  final String image;
  final bool isMe;

  /// The photograph's own dimensions, when the sender's client recorded them.
  /// Used only to keep the bubble's shape: a portrait photo cropped into a
  /// fixed landscape box loses whatever she was framing.
  final int? width;
  final int? height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(30),
      topRight: const Radius.circular(30),
      bottomLeft: Radius.circular(isMe ? 30 : 8),
      bottomRight: Radius.circular(isMe ? 8 : 30),
    );

    return Align(
      // Directional, not absolute: the sender's own bubble sits on the trailing
      // edge of the reading direction, which flips with the locale instead of
      // staying pinned to a physical side.
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: () => _openFullScreen(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260, maxHeight: 360),
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: AuthorizedMediaImage(
              url: image,
              // The bubble is 260 logical pixels wide; the full-screen view
              // below asks for the original.
              variantWidth: MediaVariants.thumbnail,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }

  /// 3:4 when the dimensions are unknown — the shape a phone camera produces
  /// held portrait, which is what most of these are.
  double get _aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 3 / 4;
    return (w / h).clamp(0.6, 1.6);
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenPhoto(url: image),
      ),
    );
  }
}

/// The photograph on its own, on black, with a way out.
class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return MediaLightbox(url: url);
  }
}
