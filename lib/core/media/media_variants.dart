/// Asking the server for a smaller copy of an image, from nothing but its URL.
///
/// The feature tables store a plain URL string — `ProductMedia.url`,
/// `Story.mediaUrl`, `User.imageUrl` — so a product card holds a link and
/// nothing else. Rewriting nine tables to carry a thumbnail column would have
/// been a migration with no reader; a naming convention costs one function and
/// works on every surface at once.
///
/// It is safe to guess. A width the server never generated falls back to the
/// original — the static mount has a handler for exactly that — so a card can
/// always ask for the small copy without knowing whether one exists.
abstract final class MediaVariants {
  /// The widths the server generates. See `ImageDerivativesService.widths`.
  static const int thumbnail = 480;
  static const int medium = 1080;

  /// `…/2026/08/<uuid>.jpg` — a public upload on this platform's own mount.
  static final _publicUpload = RegExp(
    r'^(.*/media/files/\d{4}/\d{2}/[0-9a-f-]{36})\.[a-z0-9]+$',
    caseSensitive: false,
  );

  /// `…/media/<uuid>/file` — a private one, fetched through the authorised
  /// handler rather than off disk.
  static final _privateUpload = RegExp(
    r'^.*/media/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file$',
    caseSensitive: false,
  );

  /// The URL for a copy [width] pixels across, or [url] unchanged when it is
  /// not one of ours — an external link, or a URL already pointing at a
  /// variant.
  static String at(String url, int width) {
    if (url.isEmpty) return url;

    final public = _publicUpload.firstMatch(url);
    // Always WebP: the server writes one format for every copy, whatever the
    // original was, because a third off the bytes is the entire point.
    if (public != null) return '${public.group(1)}@$width.webp';

    if (_privateUpload.hasMatch(url)) return '$url?w=$width';

    return url;
  }

  /// The small copy — what a grid, a rail or an avatar should ask for.
  static String thumb(String url) => at(url, thumbnail);

  /// Whether this URL is something the platform hosts, and therefore something
  /// [at] can do anything with.
  static bool isOurs(String url) =>
      _publicUpload.hasMatch(url) || _privateUpload.hasMatch(url);
}
