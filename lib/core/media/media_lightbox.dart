import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/media/authorized_media_image.dart';

/// Full-screen photo viewer.
///
/// The chat inbox and the shared-media gallery each carried their own copy of
/// this — same black ground, same transparent bar, same `InteractiveViewer` at
/// `maxScale: 4` — so a photo opened from a message and the same photo opened
/// from the gallery were two different screens that happened to look alike.
/// One surface now, opened through [open].
class MediaLightbox extends StatelessWidget {
  const MediaLightbox({super.key, required this.url, this.title});

  final String url;

  /// Optional caption for the bar — a sender, a date, a file name.
  final String? title;

  /// Pushes the viewer as a full-screen dialog.
  static Future<void> open(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MediaLightbox(url: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Near-black rather than pure black: the same ground the story viewer
      // uses, so full-bleed media reads as one place in the app.
      backgroundColor: DsColors.mediaGround,
      extendBodyBehindAppBar: true,
      appBar: OharaAppBar(title: title ?? '', transparent: true),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: AuthorizedMediaImage(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
