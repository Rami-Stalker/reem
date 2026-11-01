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

/// Several photos, swiped through full screen — a post's carousel opened at
/// the one she tapped.
class MediaGalleryLightbox extends StatefulWidget {
  const MediaGalleryLightbox({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
    if (urls.isEmpty) return Future.value();
    if (urls.length == 1) return MediaLightbox.open(context, url: urls.first);
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MediaGalleryLightbox(
          urls: urls,
          initialIndex: initialIndex.clamp(0, urls.length - 1),
        ),
      ),
    );
  }

  @override
  State<MediaGalleryLightbox> createState() => _MediaGalleryLightboxState();
}

class _MediaGalleryLightboxState extends State<MediaGalleryLightbox> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DsColors.mediaGround,
      extendBodyBehindAppBar: true,
      appBar: OharaAppBar(
        title: '${_index + 1} / ${widget.urls.length}',
        transparent: true,
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => Center(
          child: InteractiveViewer(
            maxScale: 4,
            child: AuthorizedMediaImage(url: widget.urls[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
