import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/features/social/domain/entities/content.dart';

/// A product she is entitled to tag, and why.
///
/// The reason travels with it because a picker that hides what she cannot tag
/// is a bug report, and one that shows it greyed out with an explanation is an
/// answer. The server decides eligibility; this is what it said.
class TaggableProduct extends Equatable {
  const TaggableProduct({
    required this.productId,
    required this.title,
    required this.basis,
    required this.eligible,
    this.imageUrl,
    this.reason,
    this.sourceOrderItemId,
  });

  final String productId;

  /// For a purchase this is the receipt's title, not the live one — it is what
  /// she was sold, and it survives the boutique renaming or delisting it.
  final String title;
  final String? imageUrl;

  /// `SELLER_OFFER` — she lists it. `PURCHASE` — it was delivered to her.
  final String basis;
  final bool eligible;
  final String? reason;

  /// The delivered line that proves a purchase.
  final String? sourceOrderItemId;

  bool get isPurchase => basis == 'PURCHASE';

  @override
  List<Object?> get props => [productId, basis, eligible];
}

/// A format she is allowed to publish, as the server describes it.
///
/// Read from the registry rather than hard-coded, so the composer offers
/// exactly what the server will accept. A list in the client that has drifted
/// from the server's is how a woman fills in a form and is refused at the end.
class ContentTypeOption extends Equatable {
  const ContentTypeOption({
    required this.key,
    required this.name,
    required this.format,
    this.description,
    this.supportsProductTags = true,
    this.supportsMedia = true,
    this.videoRequired = false,
    this.maxDurationSeconds,
    this.maxMedia,
  });

  final String key;
  final String name;
  final ContentFormat format;
  final String? description;
  final bool supportsProductTags;
  final bool supportsMedia;
  final bool videoRequired;

  /// Q142 — thirty seconds for a reel, so the ops budget survives the uplink.
  final int? maxDurationSeconds;
  final int? maxMedia;

  @override
  List<Object?> get props => [key, videoRequired, maxDurationSeconds, maxMedia];
}

/// What the composer is about to publish.
class ContentDraft extends Equatable {
  const ContentDraft({
    required this.contentType,
    this.caption = '',
    this.media = const [],
    this.productTags = const [],
    this.visibility = ContentVisibility.public,
  });

  final String contentType;
  final String caption;
  final List<MediaItem> media;

  /// Product ids, in the order she picked them.
  final List<String> productTags;
  final ContentVisibility visibility;

  ContentDraft copyWith({
    String? contentType,
    String? caption,
    List<MediaItem>? media,
    List<String>? productTags,
    ContentVisibility? visibility,
  }) {
    return ContentDraft(
      contentType: contentType ?? this.contentType,
      caption: caption ?? this.caption,
      media: media ?? this.media,
      productTags: productTags ?? this.productTags,
      visibility: visibility ?? this.visibility,
    );
  }

  @override
  List<Object?> get props => [contentType, caption, media, productTags, visibility];
}
