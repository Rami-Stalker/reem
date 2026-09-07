import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/value_objects/money.dart';

/// How one format is doing, against the others.
class ContentFormatPerformance extends Equatable {
  const ContentFormatPerformance({
    required this.format,
    required this.published,
    required this.views,
    required this.uniqueViewers,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.productClicks,
    required this.orders,
    required this.watchTimeMs,
  });

  final String format;
  final int published;
  final int views;
  final int uniqueViewers;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final int productClicks;
  final int orders;
  final int watchTimeMs;

  /// Clicks per view. The number that says whether content is *selling*
  /// rather than merely being watched — which is the whole distinction between
  /// a social app and a social-commerce one.
  double get clickThrough => views == 0 ? 0 : productClicks / views;

  @override
  List<Object?> get props => [format, published, views, productClicks];
}

/// Everything a boutique can see about one piece.
class ContentAnalytics extends Equatable {
  const ContentAnalytics({
    required this.contentId,
    required this.format,
    required this.impressions,
    required this.views,
    required this.uniqueViewers,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.reshares,
    required this.productClicks,
    required this.orders,
    required this.watchTimeMs,
    this.revenue,
  });

  final String contentId;
  final String format;
  final int impressions;
  final int views;
  final int uniqueViewers;
  final int likes;
  final int comments;
  final int saves;
  final int shares;

  /// How many women put it on their own pages. Distinct from [shares], which
  /// also counts a link sent to WhatsApp — one is reach she can see, the other
  /// is reach she cannot.
  final int reshares;
  final int productClicks;
  final int orders;
  final int watchTimeMs;
  final Money? revenue;

  @override
  List<Object?> get props => [contentId, views, reshares, productClicks];
}

/// A woman who has put a boutique's content on her own page.
///
/// [user] is null when her page is private — she is counted, never named. The
/// server decides that and never sends what it should not, so there is no way
/// for a screen to leak it by accident.
class ContentPromoter extends Equatable {
  const ContentPromoter({
    required this.isNamed,
    required this.reshares,
    required this.products,
    required this.lastAt,
    this.user,
  });

  final bool isNamed;
  final User? user;
  final int reshares;
  final int products;
  final DateTime lastAt;

  @override
  List<Object?> get props => [user?.id, isNamed, reshares, products, lastAt];
}

/// One of a boutique's pieces, ranked by how far it travelled.
class ResharedContentSummary extends Equatable {
  const ResharedContentSummary({
    required this.contentId,
    required this.reshares,
    this.title,
    this.imageUrl,
    this.format,
  });

  final String contentId;
  final int reshares;
  final String? title;
  final String? imageUrl;
  final String? format;

  @override
  List<Object?> get props => [contentId, reshares];
}

/// One of her products, ranked the same way.
class ResharedProductSummary extends Equatable {
  const ResharedProductSummary({
    required this.productId,
    required this.reshares,
    this.title,
    this.imageUrl,
  });

  final String productId;
  final int reshares;
  final String? title;
  final String? imageUrl;

  @override
  List<Object?> get props => [productId, reshares];
}

/// The whole «مين نشر منتجاتي» picture.
class ReshareSummary extends Equatable {
  const ReshareSummary({
    required this.totalReshares,
    required this.promoters,
    required this.topContent,
    required this.topProducts,
  });

  final int totalReshares;

  /// Distinct women, not reshares. A single enthusiast adding nine posts is
  /// one promoter, and a screen that says nine has told the boutique something
  /// untrue about its reach.
  final int promoters;
  final List<ResharedContentSummary> topContent;
  final List<ResharedProductSummary> topProducts;

  bool get isEmpty => totalReshares == 0;

  @override
  List<Object?> get props => [totalReshares, promoters, topContent, topProducts];
}
