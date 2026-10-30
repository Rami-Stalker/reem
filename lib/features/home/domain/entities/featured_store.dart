import 'package:equatable/equatable.dart';

/// A boutique surfaced in the "Featured stores" rail — cover + logo, trust
/// signals (verified, rating) and a few preview shots of their pieces.
class FeaturedStore extends Equatable {
  const FeaturedStore({
    required this.id,
    required this.name,
    required this.tagline,
    required this.logoUrl,
    required this.coverUrl,
    this.isVerified = false,
    this.rating,
    this.productCount = 0,
    this.followerCount = 0,
    this.isFollowing = false,
    this.previewImages = const [],
    this.adTier,
  });

  final String id;
  final String name;
  final String tagline;
  final String logoUrl;
  final String coverUrl;
  final bool isVerified;

  /// Null until customers have actually reviewed the boutique. A zero here
  /// would be shown as «0.0 ★», which reads as a bad shop rather than a new
  /// one.
  final double? rating;
  final int productCount;
  final int followerCount;
  final bool isFollowing;

  /// A few product thumbnails shown as a teaser strip on the card.
  final List<String> previewImages;

  /// Her advertising plan — `silver`, `gold`, `diamond` — or null for free.
  /// Gold and Diamond boutiques lead this rail; the badge says why.
  final String? adTier;

  FeaturedStore copyWith({bool? isFollowing, int? followerCount}) {
    return FeaturedStore(
      id: id,
      name: name,
      tagline: tagline,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      isVerified: isVerified,
      rating: rating,
      productCount: productCount,
      followerCount: followerCount ?? this.followerCount,
      isFollowing: isFollowing ?? this.isFollowing,
      previewImages: previewImages,
      adTier: adTier,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    tagline,
    logoUrl,
    coverUrl,
    isVerified,
    rating,
    productCount,
    followerCount,
    isFollowing,
    previewImages,
    adTier,
  ];
}
