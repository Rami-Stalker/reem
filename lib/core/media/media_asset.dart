/// An upload the API has accepted and stored.
///
/// The client keeps the whole record rather than only the URL, because the
/// pieces it drops are the ones a picker needs to behave well: `width`/`height`
/// let a thumbnail reserve its aspect ratio before the bytes arrive, and
/// `byteSize` is what a woman on a metered Syrian connection is actually
/// spending.
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.url,
    required this.type,
    required this.mimeType,
    required this.byteSize,
    this.thumbnailUrl,
    this.blurHash,
    this.variants = const [],
    this.width,
    this.height,
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
    id: (json['id'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
    type: (json['type'] ?? 'image').toString(),
    mimeType: (json['mime_type'] ?? '').toString(),
    byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
    thumbnailUrl: json['thumbnail_url']?.toString(),
    blurHash: json['blur_hash']?.toString(),
    variants: [
      for (final width in (json['variants'] as List?) ?? const [])
        if (width is num) width.toInt(),
    ],
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
  );

  final String id;
  final String url;

  /// `image` or `video`, as the server sniffed it — never as the file was named.
  final String type;
  final String mimeType;
  final int byteSize;

  /// The smallest copy the server made, or the original when it made none.
  final String? thumbnailUrl;

  /// Twenty-odd characters that decode to a blurred stand-in, drawn while the
  /// photograph is still arriving.
  final String? blurHash;

  /// Widths available beside the original, e.g. `[480, 1080]`.
  final List<int> variants;

  final int? width;
  final int? height;

  bool get isVideo => type == 'video';

  /// A file that is read rather than looked at — a PDF. Only ever produced by
  /// a document purpose; see the server's `MediaType.document`.
  bool get isDocument => type == 'document';

  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || h == 0) return null;
    return w / h;
  }
}

/// What an upload is for. Mirrors the server's list; the server derives who
/// may read the result from this, so the two must not drift.
enum MediaPurpose {
  product('product'),
  post('post'),
  story('story'),
  avatar('avatar'),
  storeLogo('store_logo'),
  category('category'),

  /// Identity papers. Stored privately and readable only by her and a
  /// verification reviewer — see the server's `MediaVisibility`.
  verification('verification'),

  /// Sent into a conversation. Private for the same reason the conversation
  /// is: the readers are the people in it, and nobody else — not support, not
  /// an administrator.
  chat('chat'),

  /// A garment in her own wardrobe. Private, and stored with no reader but
  /// her: photographing her clothes means photographing her bedroom and her
  /// mirror. Unlike the other private purposes it carries no retention clock —
  /// this picture is the permanent illustration of something she owns, and it
  /// goes when she deletes the piece.
  closet('closet'),

  /// A photograph of the fault, attached to a return request. Public, unlike
  /// the purposes above it: the boutique she is claiming against has to be
  /// able to see it, and so does whoever arbitrates if they disagree. See the
  /// server's `PRIVATE_PURPOSES` for why that is a decision rather than an
  /// oversight.
  returnEvidence('return_evidence'),

  /// A photograph of the piece on her, attached to a product review under
  /// «تقييمات من بمقاسي». Public — showing other women how it sat is the
  /// point — and moderated with the review it belongs to.
  review('review');

  const MediaPurpose(this.wire);

  final String wire;

  /// Mirrors the server's purpose→visibility mapping.
  ///
  /// The client does not decide this — the server does, and it ignores
  /// anything the client claims. Knowing it anyway matters for one thing: a
  /// private asset must never be handed to `CachedNetworkImage`. That would
  /// fail (the bytes need a bearer token the image loader does not send) and,
  /// worse, would write a photograph of somebody's national ID into a shared
  /// on-disk cache if it ever succeeded.
  /// The server's private set is `verification`, `chat`, `visual_search`,
  /// `try_on` and `closet`. Only the three the client can actually upload as
  /// are listed here; `closet` was missing, which made this getter disagree
  /// with the mapping its own comment promises to mirror — and a closet
  /// photograph is a picture of her bedroom and her mirror.
  bool get isPrivate =>
      this == MediaPurpose.verification ||
      this == MediaPurpose.chat ||
      this == MediaPurpose.closet;
}
