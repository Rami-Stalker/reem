import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/user.dart';

/// What a piece of content *is* — the format, not the table.
///
/// Formats are registry rows on the server, so this enum is a rendering hint
/// rather than a closed set: an unknown key falls back to [post] and draws as
/// a card, which is the shape that degrades most gracefully. A format added
/// server-side therefore appears in the feed on the day it is enabled, looking
/// plain rather than broken.
enum ContentFormat {
  post,
  reel,
  story,
  offer,
  collection,
  live;

  static ContentFormat fromWire(String? value) => switch (value) {
    'product_post' || 'post' => ContentFormat.post,
    'reel' => ContentFormat.reel,
    'story' => ContentFormat.story,
    'flash_offer' => ContentFormat.offer,
    'collection' => ContentFormat.collection,
    'live_stream' => ContentFormat.live,
    _ => ContentFormat.post,
  };

  bool get isVideo => this == ContentFormat.reel;
  bool get isEphemeral => this == ContentFormat.story;
}

/// Who wrote it — as she was at the moment she wrote it.
///
/// Deliberately not derived from the author's current role. A shopper who
/// later opens a boutique did not retroactively write marketing, and a product
/// page whose «نساء يرتدينها» rail reclassified her year-old look would be
/// lying about its own evidence.
enum ContentAuthorKind {
  seller,
  customer,
  platform;

  static ContentAuthorKind fromWire(String? value) => switch (value) {
    'seller' => ContentAuthorKind.seller,
    'customer' => ContentAuthorKind.customer,
    _ => ContentAuthorKind.platform,
  };

  bool get isCustomer => this == ContentAuthorKind.customer;
  bool get isSeller => this == ContentAuthorKind.seller;
}

/// Active / قيد المراجعة / محذوف.
///
/// Derived server-side from two enums, and never recomputed here. The client
/// asking the same question a different way is how the app and the moderation
/// queue come to disagree about whether something is visible.
enum ContentModerationState {
  active,
  underReview,
  removed;

  static ContentModerationState fromWire(String? value) => switch (value) {
    'removed' => ContentModerationState.removed,
    'under_review' => ContentModerationState.underReview,
    _ => ContentModerationState.active,
  };
}

/// Where a piece of content is in its own life.
enum ContentStatus {
  draft,
  inReview,
  scheduled,
  published,
  expired,
  archived,
  rejected,
  deleted,
  removed;

  static ContentStatus fromWire(String? value) => switch (value) {
    'draft' => ContentStatus.draft,
    'in_review' => ContentStatus.inReview,
    'scheduled' => ContentStatus.scheduled,
    'published' => ContentStatus.published,
    'expired' => ContentStatus.expired,
    'archived' => ContentStatus.archived,
    'rejected' => ContentStatus.rejected,
    'deleted' => ContentStatus.deleted,
    'removed' => ContentStatus.removed,
    _ => ContentStatus.draft,
  };

  bool get isLive => this == ContentStatus.published;
}

/// Who may see it.
enum ContentVisibility {
  public,
  followers,
  unlisted,
  private;

  static ContentVisibility fromWire(String? value) => switch (value) {
    'followers' => ContentVisibility.followers,
    'unlisted' => ContentVisibility.unlisted,
    'private' => ContentVisibility.private,
    _ => ContentVisibility.public,
  };

  String get wire => switch (this) {
    ContentVisibility.public => 'PUBLIC',
    ContentVisibility.followers => 'FOLLOWERS',
    ContentVisibility.unlisted => 'UNLISTED',
    ContentVisibility.private => 'PRIVATE',
  };
}

/// A shoppable tag: a real product, on a real piece of content.
///
/// [product] is the catalogue entry, not a copy of it — so tapping through
/// reaches the boutique's own page with its own price and stock, which is the
/// whole point of the feature. [x] and [y] are normalised 0–1 hotspot
/// coordinates when the composer placed one, and null when she did not.
class ContentProductTag extends Equatable {
  const ContentProductTag({
    required this.id,
    required this.product,
    this.displayLabel,
    this.x,
    this.y,
    this.sortOrder = 0,
  });

  final String id;
  final Product product;
  final String? displayLabel;
  final double? x;
  final double? y;
  final int sortOrder;

  bool get hasHotspot => x != null && y != null;

  @override
  List<Object?> get props => [id, product.id, x, y, sortOrder];
}

/// What this viewer has done to this piece.
///
/// A counter cannot answer "have *I* liked it", which is the one thing every
/// card must render — so the server sends both, and this is the half that is
/// hers.
class ContentViewerState extends Equatable {
  const ContentViewerState({
    this.isLiked = false,
    this.myReaction,
    this.isSaved = false,
    this.isReshared = false,
  });

  final bool isLiked;
  final String? myReaction;
  final bool isSaved;
  final bool isReshared;

  ContentViewerState copyWith({
    bool? isLiked,
    String? myReaction,
    bool clearReaction = false,
    bool? isSaved,
    bool? isReshared,
  }) {
    return ContentViewerState(
      isLiked: isLiked ?? this.isLiked,
      myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
      isSaved: isSaved ?? this.isSaved,
      isReshared: isReshared ?? this.isReshared,
    );
  }

  @override
  List<Object?> get props => [isLiked, myReaction, isSaved, isReshared];
}

/// The numbers under a piece.
class ContentCounts extends Equatable {
  const ContentCounts({
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
    this.productClicks = 0,
  });

  final int views;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final int productClicks;

  ContentCounts copyWith({
    int? likes,
    int? comments,
    int? saves,
    int? shares,
  }) {
    return ContentCounts(
      views: views,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      saves: saves ?? this.saves,
      shares: shares ?? this.shares,
      productClicks: productClicks,
    );
  }

  @override
  List<Object?> get props => [views, likes, comments, saves, shares, productClicks];
}

/// One piece of social content — a post, a reel or a story.
///
/// One entity for all three because they differ by *format*, and the format is
/// registry data. A separate `Reel` class would mean every feed, every card and
/// every interaction path learning a second shape to say the same things.
class Content extends Equatable {
  const Content({
    required this.id,
    required this.author,
    required this.authorKind,
    required this.format,
    required this.status,
    required this.moderationState,
    required this.visibility,
    required this.createdAt,
    this.title,
    this.body,
    this.media = const [],
    this.productTags = const [],
    this.counts = const ContentCounts(),
    this.viewer = const ContentViewerState(),
    this.publishedAt,
    this.expiresAt,
    this.removalReason,
  });

  final String id;
  final User author;
  final ContentAuthorKind authorKind;
  final ContentFormat format;
  final ContentStatus status;
  final ContentModerationState moderationState;
  final ContentVisibility visibility;
  final String? title;
  final String? body;
  final List<MediaItem> media;
  final List<ContentProductTag> productTags;
  final ContentCounts counts;
  final ContentViewerState viewer;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  /// Why a moderator took it down. Only ever sent to the woman who wrote it.
  final String? removalReason;

  /// The caption, wherever it lives. `body` on the wire; the payload carries a
  /// copy that the composer edits.
  String get caption => body ?? '';

  bool get hasMedia => media.isNotEmpty;
  bool get hasProducts => productTags.isNotEmpty;

  /// The first tagged piece — what a single "shop this" plate points at.
  ContentProductTag? get primaryTag =>
      productTags.isEmpty ? null : productTags.first;

  MediaItem? get cover => media.isEmpty ? null : media.first;

  /// The clip, for a reel. Null when the format is not a video one or the
  /// media has not arrived.
  MediaItem? get video {
    for (final item in media) {
      if (item.isVideo) return item;
    }
    return null;
  }

  /// The still picture a share carries — and the one a messenger draws as the
  /// link preview.
  ///
  /// Falls through to the first tagged piece, because a post *about* a dress
  /// with no photograph of its own is still, to everyone who receives it, a
  /// post about that dress. The alternative was a 40-pixel avatar blown up to
  /// fill a preview card.
  String? get shareImageUrl =>
      media.stillImageUrl ?? primaryTag?.product.media.stillImageUrl;

  bool get isRemoved => moderationState == ContentModerationState.removed;
  bool get isUnderReview =>
      moderationState == ContentModerationState.underReview;

  /// A story that has not run out yet.
  bool get isLiveStory {
    final expiry = expiresAt;
    if (format != ContentFormat.story || expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  Content copyWith({
    ContentCounts? counts,
    ContentViewerState? viewer,
    ContentStatus? status,
    ContentModerationState? moderationState,
    String? body,
    ContentVisibility? visibility,
  }) {
    return Content(
      id: id,
      author: author,
      authorKind: authorKind,
      format: format,
      status: status ?? this.status,
      moderationState: moderationState ?? this.moderationState,
      visibility: visibility ?? this.visibility,
      title: title,
      body: body ?? this.body,
      media: media,
      productTags: productTags,
      counts: counts ?? this.counts,
      viewer: viewer ?? this.viewer,
      createdAt: createdAt,
      publishedAt: publishedAt,
      expiresAt: expiresAt,
      removalReason: removalReason,
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    moderationState,
    visibility,
    body,
    counts,
    viewer,
  ];
}

/// Somebody else's post, on her page.
///
/// A wrapper rather than a copy with the resharer's name substituted in: the
/// original is nested whole, so anything that renders [content] gets the
/// boutique's name, its products and its link for free — and cannot
/// accidentally present the resharer as the source. That is the requirement,
/// expressed as a type.
class ContentReshare extends Equatable {
  const ContentReshare({
    required this.id,
    required this.resharer,
    required this.content,
    required this.resharedAt,
    this.note,
  });

  final String id;
  final User resharer;
  final Content content;
  final DateTime resharedAt;

  /// What she said about it. The only part of a reshare that is hers.
  final String? note;

  @override
  List<Object?> get props => [id, resharer.id, content.id, resharedAt];
}

/// An entry on a woman's page: something she published, or something she added.
sealed class TimelineEntry extends Equatable {
  const TimelineEntry();

  /// The content being shown, whoever put it there.
  Content get content;

  /// A stable id for a list key. A reshare and its original are different
  /// entries and must not collide.
  String get entryId;
}

final class OwnContentEntry extends TimelineEntry {
  const OwnContentEntry(this.content);

  @override
  final Content content;

  @override
  String get entryId => 'own:${content.id}';

  @override
  List<Object?> get props => [content];
}

final class ResharedContentEntry extends TimelineEntry {
  const ResharedContentEntry(this.reshare);

  final ContentReshare reshare;

  @override
  Content get content => reshare.content;

  @override
  String get entryId => 'reshare:${reshare.id}';

  @override
  List<Object?> get props => [reshare];
}
